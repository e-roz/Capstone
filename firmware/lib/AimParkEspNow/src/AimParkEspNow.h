// AimPark — the ESP-NOW link shared by the hub, the gate nodes and the slot
// sensors. Every sketch includes this, so the keys and the packet format can
// never drift apart between them.
//
// Star layout: each node talks to the hub only, never to another node.
//
//     G1 ──┐                ┌── S1
//          ├── HUB ── USB ──┤        (HUB is plugged into the site server)
//     G2 ──┘                └── S2
//
// S1 and S2 each watch several slots (up to MAX_SLOTS), one HC-SR04 per slot.
//
// Nothing here names a particular board. A new gate or sensor board asks to
// join (MSG_PAIR_REQ, broadcast) and blinks fast; the installer accepts it on
// the guard panel and says what it is — Gate 1, Sensor board 2 — and the hub
// answers (MSG_PAIR_OK) and from then on calls it G1, S2, … The hub keeps
// the names, each node keeps its hub, both in flash. Holding a node's BOOT
// button 5 s makes it forget its hub (see AimParkNode.h).

#pragma once

#include <Arduino.h>
#include <WiFi.h>
#include <esp_now.h>
#include <esp_wifi.h>
#include <esp_idf_version.h>
#include <freertos/FreeRTOS.h>
#include <freertos/queue.h>

// Keys. Paired traffic is encrypted, so a stray ESP32 can't open a barrier or
// fake a slot. To use keys of your own, create AimParkEspNowKeys.h next to this
// file (it is git-ignored) with the same two #defines, then reflash every board.
#if __has_include("AimParkEspNowKeys.h")
#include "AimParkEspNowKeys.h"
#else
#define AIMPARK_PMK "AimPark-PMK-2026"   // exactly 16 characters
#define AIMPARK_LMK "AimPark-LMK-2026"   // exactly 16 characters
#endif
static_assert(sizeof(AIMPARK_PMK) == 17, "AIMPARK_PMK must be exactly 16 characters");
static_assert(sizeof(AIMPARK_LMK) == 17, "AIMPARK_LMK must be exactly 16 characters");

namespace aimpark {

// ── Roles ────────────────────────────────────────────────────────────────────
// Fixed by the sketch a board runs, not by which board it is.
enum Role : uint8_t { ROLE_HUB = 0, ROLE_GATE = 1, ROLE_SENSOR = 2 };

inline const char* roleName(uint8_t role) {
  switch (role) {
    case ROLE_HUB:    return "HUB";
    case ROLE_GATE:   return "GATE";
    case ROLE_SENSOR: return "SENSOR";
    default:          return "UNKNOWN";
  }
}

// Every board must sit on the same channel. None of them joins a WiFi network,
// so nothing else moves them off it.
constexpr uint8_t WIFI_CHANNEL = 1;

// Nodes check in this often; the hub calls a node offline after three missed.
constexpr unsigned long HEARTBEAT_MS     = 5000;
constexpr unsigned long OFFLINE_AFTER_MS = 3 * HEARTBEAT_MS + 1000;

// An unpaired node repeats its request this often.
constexpr unsigned long PAIR_REQUEST_MS = 2000;

// Holding BOOT this long makes a node forget its hub.
constexpr unsigned long FORGET_HOLD_MS = 5000;
constexpr uint8_t PIN_BOOT_BUTTON = 0;

// The radio holds only a few encrypted peers; this stays under its limit.
constexpr uint8_t MAX_NODES = 6;

// ── Packets ──────────────────────────────────────────────────────────────────
enum MsgType : uint8_t {
  MSG_HELLO    = 1,  // gate -> hub     heartbeat
  MSG_UID      = 2,  // gate -> hub     a card was tapped
  MSG_RESULT   = 3,  // hub  -> gate    the server's answer to that tap
  MSG_OPEN     = 4,  // hub  -> gate    the guard's "Open gate" button
  MSG_SLOT     = 5,  // sensor -> hub   every slot's state; doubles as its heartbeat
  MSG_PAIR_REQ = 6,  // node -> all     unpaired, asking to join (broadcast, plain)
  MSG_PAIR_OK  = 7,  // hub  -> node    accepted; the sender is your hub (plain)
  MSG_FORGET   = 8,  // hub  -> node    you were removed; ask to join again
};

// Bumped whenever Packet changes, so a board on old firmware is ignored
// rather than misread. Reflash every board together.
constexpr uint8_t PROTOCOL_VERSION = 3;
constexpr size_t UID_CHARS = 20;   // a 10-byte UID in hex

// One sensor board watches several slots, each with its own HC-SR04.
constexpr uint8_t MAX_SLOTS = 10;

struct __attribute__((packed)) Packet {
  uint8_t  version;
  uint8_t  type;
  uint8_t  role;        // The sender's Role.
  uint16_t seq;         // Per sender. RESULT echoes the seq of the UID it answers.
  uint8_t  flag;        // RESULT: 1 = open.
  char     uid[UID_CHARS + 1];

  // SLOT only. The whole board in one packet, so the hub sees every slot
  // change together and a heartbeat costs one send, not one per slot.
  uint8_t  slotCount;
  uint16_t occupiedMask;           // Bit i set = slot i + 1 occupied.
  uint16_t distanceMm[MAX_SLOTS];  // 0 = nothing in range.
};

struct Incoming {
  uint8_t mac[6];
  Packet packet;
};

static const uint8_t BROADCAST[6] = {0xFF, 0xFF, 0xFF, 0xFF, 0xFF, 0xFF};

inline Packet makePacket(MsgType type, Role role, uint16_t seq) {
  Packet p;
  memset(&p, 0, sizeof p);
  p.version = PROTOCOL_VERSION;
  p.type = type;
  p.role = role;
  p.seq = seq;
  return p;
}

// ── Ids ──────────────────────────────────────────────────────────────────────
// A board's id is its MAC as 12 hex digits, e.g. 582ABDD0A36C: what the
// pairing screen shows, and what to write on its label.
inline String macToId(const uint8_t* mac) {
  char text[13];
  snprintf(text, sizeof text, "%02X%02X%02X%02X%02X%02X",
           mac[0], mac[1], mac[2], mac[3], mac[4], mac[5]);
  return String(text);
}

inline bool idToMac(const String& id, uint8_t* mac) {
  if (id.length() != 12) return false;
  for (int i = 0; i < 6; i++) {
    char pair[3] = {id[i * 2], id[i * 2 + 1], 0};
    char* end = nullptr;
    long value = strtol(pair, &end, 16);
    if (end != pair + 2) return false;
    mac[i] = (uint8_t)value;
  }
  return true;
}

inline String selfId() {
  uint8_t mac[6];
  esp_wifi_get_mac(WIFI_IF_STA, mac);
  return macToId(mac);
}

// ── Callbacks ────────────────────────────────────────────────────────────────
// Both run on the WiFi task, so they only hand data over; the sketch's loop()
// does the work.
#if ESP_IDF_VERSION >= ESP_IDF_VERSION_VAL(5, 0, 0)
#define AIMPARK_RECV_ARGS const esp_now_recv_info_t* info, const uint8_t* data, int len
#define AIMPARK_RECV_MAC  (info->src_addr)
#else
#define AIMPARK_RECV_ARGS const uint8_t* mac, const uint8_t* data, int len
#define AIMPARK_RECV_MAC  (mac)
#endif

#if ESP_IDF_VERSION >= ESP_IDF_VERSION_VAL(5, 5, 0)
#define AIMPARK_SENT_ARGS const wifi_tx_info_t* info, esp_now_send_status_t status
#else
#define AIMPARK_SENT_ARGS const uint8_t* mac, esp_now_send_status_t status
#endif

namespace detail {
static QueueHandle_t inbox = nullptr;
static volatile bool sendDone = false;
static volatile bool sendOk = false;

static void onReceive(AIMPARK_RECV_ARGS) {
  if (len != (int)sizeof(Packet)) return;

  Incoming in;
  memcpy(in.mac, AIMPARK_RECV_MAC, 6);
  memcpy(&in.packet, data, sizeof(Packet));
  if (in.packet.version != PROTOCOL_VERSION) return;
  in.packet.uid[UID_CHARS] = '\0';

  xQueueSend(inbox, &in, 0);                      // Full inbox: drop, never block.
}

static void onSent(AIMPARK_SENT_ARGS) {
  sendOk = (status == ESP_NOW_SEND_SUCCESS);
  sendDone = true;
}
}  // namespace detail

// ── Setup ────────────────────────────────────────────────────────────────────
inline bool begin() {
  WiFi.mode(WIFI_STA);
  WiFi.disconnect();
  esp_wifi_set_channel(WIFI_CHANNEL, WIFI_SECOND_CHAN_NONE);

  if (esp_now_init() != ESP_OK) return false;
  esp_now_set_pmk((const uint8_t*)AIMPARK_PMK);

  detail::inbox = xQueueCreate(16, sizeof(Incoming));
  esp_now_register_recv_cb(detail::onReceive);
  esp_now_register_send_cb(detail::onSent);
  return detail::inbox != nullptr;
}

// Adds a peer, or changes it if it is already there (e.g. from plain to
// encrypted once pairing is done).
inline bool setPeer(const uint8_t* mac, bool encrypt) {
  esp_now_peer_info_t peer;
  memset(&peer, 0, sizeof peer);
  memcpy(peer.peer_addr, mac, 6);
  peer.channel = WIFI_CHANNEL;
  peer.ifidx = WIFI_IF_STA;
  peer.encrypt = encrypt;
  if (encrypt) memcpy(peer.lmk, AIMPARK_LMK, 16);

  if (esp_now_is_peer_exist(mac)) return esp_now_mod_peer(&peer) == ESP_OK;
  return esp_now_add_peer(&peer) == ESP_OK;
}

inline void removePeer(const uint8_t* mac) {
  if (esp_now_is_peer_exist(mac)) esp_now_del_peer(mac);
}

// ── Traffic ──────────────────────────────────────────────────────────────────
// Sends and waits for the other board's radio to acknowledge it. True only
// once it has (a broadcast is never acknowledged, so it is true once sent).
// A retry can deliver the same packet twice when an ack is lost, which is why
// receivers drop repeated seqs.
inline bool sendConfirmed(const uint8_t* to, const Packet& packet, uint8_t attempts = 3) {
  for (uint8_t i = 0; i < attempts; i++) {
    detail::sendDone = false;
    if (esp_now_send(to, (const uint8_t*)&packet, sizeof packet) == ESP_OK) {
      unsigned long started = millis();
      while (!detail::sendDone && millis() - started < 200) delay(1);
      if (detail::sendDone && detail::sendOk) return true;
    }
    delay(30);
  }
  return false;
}

// Takes the next packet off the inbox, if one is waiting.
inline bool receive(Incoming& out) {
  return detail::inbox && xQueueReceive(detail::inbox, &out, 0) == pdTRUE;
}

}  // namespace aimpark
