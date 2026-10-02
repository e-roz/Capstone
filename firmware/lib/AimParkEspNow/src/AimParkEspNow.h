// AimPark — the ESP-NOW link shared by the hub, the gate nodes and the slot
// sensors. Every sketch includes this, so the board list, the keys and the
// packet format can never drift apart between them.
//
// Star layout: each node talks to the hub only, never to another node.
//
//     G1 ──┐                ┌── S1
//          ├── HUB ── USB ──┤        (HUB is plugged into the site server)
//     G2 ──┘                └── S2
//
// S1 and S2 each watch several slots (up to MAX_SLOTS), one HC-SR04 per slot.
//
// A board works out who it is from its own MAC, so the gate sketch is the same
// file on G1 and G2, and the sensor sketch the same on S1 and S2.

#pragma once

#include <Arduino.h>
#include <WiFi.h>
#include <esp_now.h>
#include <esp_wifi.h>
#include <esp_idf_version.h>
#include <freertos/FreeRTOS.h>
#include <freertos/queue.h>

// Keys. The link is encrypted, so a stray ESP32 can't open a barrier or fake a
// slot. To use keys of your own, create AimParkEspNowKeys.h next to this file
// (it is git-ignored) with the same two #defines, then reflash all five boards.
#if __has_include("AimParkEspNowKeys.h")
#include "AimParkEspNowKeys.h"
#else
#define AIMPARK_PMK "AimPark-PMK-2026"   // exactly 16 characters
#define AIMPARK_LMK "AimPark-LMK-2026"   // exactly 16 characters
#endif
static_assert(sizeof(AIMPARK_PMK) == 17, "AIMPARK_PMK must be exactly 16 characters");
static_assert(sizeof(AIMPARK_LMK) == 17, "AIMPARK_LMK must be exactly 16 characters");

namespace aimpark {

// ── Boards ───────────────────────────────────────────────────────────────────
enum Node : uint8_t { HUB = 0, G1, G2, S1, S2, NODE_COUNT, UNKNOWN_NODE = 0xFF };
enum Role : uint8_t { ROLE_HUB, ROLE_GATE, ROLE_SENSOR };

struct Board {
  const char* name;
  Role role;
  uint8_t mac[6];
};

// Read off each chip with esptool on 2026-09-29. The MAC belongs to the chip,
// so label the boards: one that swaps places takes its identity with it.
static const Board BOARDS[NODE_COUNT] = {
  {"HUB", ROLE_HUB,    {0x20, 0x50, 0x0D, 0xCF, 0x87, 0x18}},
  {"G1",  ROLE_GATE,   {0x58, 0x2A, 0xBD, 0xD0, 0xA3, 0x6C}},
  {"G2",  ROLE_GATE,   {0x20, 0x50, 0x0D, 0xCF, 0xCD, 0x00}},
  {"S1",  ROLE_SENSOR, {0x58, 0x2A, 0xBD, 0xD7, 0x5C, 0xFC}},
  {"S2",  ROLE_SENSOR, {0x4C, 0xC3, 0x82, 0xED, 0x1D, 0xA4}},
};

// Every board must sit on the same channel. None of them joins a WiFi network,
// so nothing else moves them off it.
constexpr uint8_t WIFI_CHANNEL = 1;

// Nodes check in this often; the hub calls a node offline after three missed.
constexpr unsigned long HEARTBEAT_MS     = 5000;
constexpr unsigned long OFFLINE_AFTER_MS = 3 * HEARTBEAT_MS + 1000;

// ── Packets ──────────────────────────────────────────────────────────────────
enum MsgType : uint8_t {
  MSG_HELLO  = 1,  // gate -> hub    heartbeat
  MSG_UID    = 2,  // gate -> hub    a card was tapped
  MSG_RESULT = 3,  // hub  -> gate   the server's answer to that tap
  MSG_OPEN   = 4,  // hub  -> gate   the guard's "Open gate" button
  MSG_SLOT   = 5,  // sensor -> hub  every slot's state; doubles as its heartbeat
};

// Bumped whenever Packet changes, so a board on old firmware is ignored
// rather than misread. Reflash all five together.
constexpr uint8_t PROTOCOL_VERSION = 2;
constexpr size_t UID_CHARS = 20;   // a 10-byte UID in hex

// One sensor board watches several slots, each with its own HC-SR04.
constexpr uint8_t MAX_SLOTS = 10;

struct __attribute__((packed)) Packet {
  uint8_t  version;
  uint8_t  type;
  uint16_t seq;         // Per sender. RESULT echoes the seq of the UID it answers.
  uint8_t  flag;        // RESULT: 1 = open.
  char     uid[UID_CHARS + 1];

  // SLOT only. The whole board in one packet, so the hub sees every slot
  // change together and a heartbeat costs one send, not one per slot.
  uint8_t  slotCount;
  uint16_t occupiedMask;           // Bit i set = slot i + 1 occupied.
  uint16_t distanceMm[MAX_SLOTS];  // 0 = nothing in range.
};

inline Packet makePacket(MsgType type, uint16_t seq) {
  Packet p;
  memset(&p, 0, sizeof p);
  p.version = PROTOCOL_VERSION;
  p.type = type;
  p.seq = seq;
  return p;
}

struct Incoming {
  Node from;
  Packet packet;
};

// ── Lookup ───────────────────────────────────────────────────────────────────
inline Node nodeForMac(const uint8_t* mac) {
  for (uint8_t i = 0; i < NODE_COUNT; i++) {
    if (memcmp(BOARDS[i].mac, mac, 6) == 0) return (Node)i;
  }
  return UNKNOWN_NODE;
}

inline Node nodeForName(const String& name) {
  for (uint8_t i = 0; i < NODE_COUNT; i++) {
    if (name.equalsIgnoreCase(BOARDS[i].name)) return (Node)i;
  }
  return UNKNOWN_NODE;
}

inline String macToString(const uint8_t* mac) {
  char text[18];
  snprintf(text, sizeof text, "%02x:%02x:%02x:%02x:%02x:%02x",
           mac[0], mac[1], mac[2], mac[3], mac[4], mac[5]);
  return String(text);
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
  Node from = nodeForMac(AIMPARK_RECV_MAC);
  if (from == UNKNOWN_NODE) return;               // Not one of ours.
  if (len != (int)sizeof(Packet)) return;

  Incoming in;
  in.from = from;
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
// Which board this is, from its own MAC. UNKNOWN_NODE means it isn't in
// BOARDS at all.
inline Node identifySelf() {
  WiFi.mode(WIFI_STA);
  uint8_t mac[6];
  esp_wifi_get_mac(WIFI_IF_STA, mac);
  return nodeForMac(mac);
}

inline String selfMac() {
  uint8_t mac[6];
  esp_wifi_get_mac(WIFI_IF_STA, mac);
  return macToString(mac);
}

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

inline bool addPeer(Node node) {
  esp_now_peer_info_t peer;
  memset(&peer, 0, sizeof peer);
  memcpy(peer.peer_addr, BOARDS[node].mac, 6);
  peer.channel = WIFI_CHANNEL;
  peer.ifidx = WIFI_IF_STA;
  peer.encrypt = true;
  memcpy(peer.lmk, AIMPARK_LMK, 16);
  return esp_now_add_peer(&peer) == ESP_OK;
}

// ── Traffic ──────────────────────────────────────────────────────────────────
// Sends and waits for the other board's radio to acknowledge it. True only
// once it has. A retry can deliver the same packet twice when an ack is lost,
// which is why receivers drop repeated seqs.
inline bool sendConfirmed(Node to, const Packet& packet, uint8_t attempts = 3) {
  for (uint8_t i = 0; i < attempts; i++) {
    detail::sendDone = false;
    if (esp_now_send(BOARDS[to].mac, (const uint8_t*)&packet, sizeof packet) == ESP_OK) {
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
