// AimPark — the node side of pairing, shared by the gate and sensor sketches.
//
// A node is either paired (it knows its hub's MAC, kept in flash) or not.
// Unpaired, it broadcasts a join request every 2 s and blinks its on-board
// LED fast; the installer accepts it on the guard panel and names it.
// Paired, it talks to that hub only, encrypted.
//
// Holding BOOT for 5 s forgets the hub, for a board being replaced or moved.

#pragma once

#include <Preferences.h>
#include "AimParkEspNow.h"

namespace aimpark {

class NodeLink {
 public:
  explicit NodeLink(Role role, int ledPin = 2) : role_(role), ledPin_(ledPin) {}

  // False only when the radio itself failed to start.
  bool begin() {
    pinMode(PIN_BOOT_BUTTON, INPUT_PULLUP);
    if (ledPin_ >= 0) pinMode(ledPin_, OUTPUT);

    if (!aimpark::begin()) return false;
    setPeer(BROADCAST, false);
    seq_ = (uint16_t)esp_random();   // So the hub can't mistake a reboot for a repeat.

    prefs_.begin("aimpark", false);
    paired_ = prefs_.getBytes("hub", hub_, 6) == 6;
    if (paired_ && !setPeer(hub_, true)) paired_ = false;

    Serial.printf("I am %s (%s). ", selfId().c_str(), roleName(role_));
    if (paired_) Serial.printf("Paired with hub %s.\n", macToId(hub_).c_str());
    else         Serial.println("Not paired yet: accept me on the Devices screen.");
    return true;
  }

  bool paired() const { return paired_; }

  // True once, right after pairing: a sensor sends its reading at once.
  bool takeJustPaired() {
    bool was = justPaired_;
    justPaired_ = false;
    return was;
  }
  uint16_t nextSeq() { return ++seq_; }

  // Call every loop. Handles the join requests, the BOOT button and the LED.
  // Hands back the next packet from the hub, if there is one.
  bool poll(Incoming& out) {
    checkBootButton();
    blink();

    if (!paired_ && millis() - lastRequestAt_ >= PAIR_REQUEST_MS) {
      lastRequestAt_ = millis();
      sendConfirmed(BROADCAST, makePacket(MSG_PAIR_REQ, role_, nextSeq()), 1);
    }

    Incoming in;
    while (receive(in)) {
      if (!paired_) {
        if (in.packet.type == MSG_PAIR_OK && in.packet.role == ROLE_HUB) adopt(in.mac);
        continue;
      }
      if (memcmp(in.mac, hub_, 6) != 0) continue;   // Only our hub gives orders.
      if (in.packet.type == MSG_FORGET) {
        Serial.println("The hub removed me. Asking to join again.");
        forget();
        continue;
      }
      out = in;
      return true;
    }
    return false;
  }

  // Sends to the hub. False when unpaired or the hub didn't acknowledge it.
  bool send(const Packet& p, uint8_t attempts = 3) {
    return paired_ && sendConfirmed(hub_, p, attempts);
  }

  void forget() {
    if (paired_) removePeer(hub_);
    paired_ = false;
    prefs_.remove("hub");
    lastRequestAt_ = 0;
  }

  // The sketch's own use of the LED (e.g. a sensor showing "occupied") while
  // paired; unpaired, the fast blink wins.
  void setLed(bool on) { ledOn_ = on; }

 private:
  void adopt(const uint8_t* mac) {
    if (!setPeer(mac, true)) {
      Serial.println("Could not add the hub as a peer.");
      return;
    }
    memcpy(hub_, mac, 6);
    prefs_.putBytes("hub", hub_, 6);
    paired_ = true;
    Serial.printf("Paired with hub %s.\n", macToId(hub_).c_str());

    // Check in at once, so the Devices screen shows it online straight away.
    send(makePacket(MSG_HELLO, role_, nextSeq()), 3);
    justPaired_ = true;
  }

  void checkBootButton() {
    bool down = digitalRead(PIN_BOOT_BUTTON) == LOW;
    if (!down) {
      bootDownAt_ = 0;
      return;
    }
    if (bootDownAt_ == 0) bootDownAt_ = millis();
    if (paired_ && millis() - bootDownAt_ >= FORGET_HOLD_MS) {
      Serial.println("BOOT held: forgetting the hub.");
      forget();
    }
  }

  void blink() {
    if (ledPin_ < 0) return;
    bool on = paired_ ? ledOn_ : (millis() / 150) % 2 == 0;
    digitalWrite(ledPin_, on ? HIGH : LOW);
  }

  Role role_;
  int ledPin_;
  Preferences prefs_;
  uint8_t hub_[6] = {0};
  bool paired_ = false;
  bool ledOn_ = false;
  bool justPaired_ = false;
  uint16_t seq_ = 0;
  unsigned long lastRequestAt_ = 0;
  unsigned long bootDownAt_ = 0;
};

}  // namespace aimpark
