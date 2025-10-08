# 🗺️ Map Module Specification

## 📖 Overview

This module manages:

* Map textures and layered rendering
* Collision geometry
* Interactive and event-driven objects
* Entity and player spawners
* Layer visibility and signal-based logic

Camera boundaries are **not** handled by this module.

---

## 🗂️ File Structure

Each map folder:

```
/maps/
  home/
    home.json
    home_script.lua
    textures/
      bg.png
      fg.png
      roof.png
```

* `.json` → defines geometry, textures, objects, and triggers
* `.lua` → contains functions called by the map logic

---

## ⚙️ General JSON Structure

```json
{
  "general": {
    "background": {
      "texture": "textures/bg.png",
      "layer": 0
    },
    "foreground": {
      "texture": "textures/fg.png",
      "layer": 100
    }
  },

  "groups": {
    "home1": {
      "origin": [100, 200],
      "collision": [
        [[0, 0], [200, 0], [200, 150], [0, 150]]
      ],
      "textures": [
        {
          "name": "roof",
          "texture": "textures/roof.png",
          "layer": 50,
          "position": [0, 0],
          "hide_area": [[50, 50], [150, 50], [150, 120], [50, 120]]
        }
      ],
      "objects": [
        {
          "id": "door_1",
          "type": "interactable",
          "position": [80, 140],
          "trigger": {
            "on_interact": "openDoor"
          }
        },
        {
          "id": "light_switch",
          "type": "interactable",
          "position": [90, 130],
          "trigger": {
            "on_interact": "toggleLight"
          }
        }
      ]
    }
  },

  "spawners": {
    "player_spawn_1": {
      "type": "player",
      "index": 1,
      "position": [120, 160]
    },
    "enemy_wave_1": {
      "type": "wave",
      "position": [300, 400],
      "spawn_range": 150,
      "entities": ["enemy_basic", "enemy_fast"]
    },
    "trigger_spawn": {
      "type": "single",
      "position": [500, 500],
      "entity": "boss_demon"
    }
  }
}
```

---

## 🧱 Groups

Each `group` defines a logical structure (room, area, building) with:

* **origin**: base point for relative coordinates
* **collision**: polygons defining solid areas
* **textures**: optional layers with relative position and hide areas
* **objects**: interactables and event-driven elements

---

## 🧍 Objects and Triggers

Objects support **multiple triggers** that call functions in the paired script file.
They can represent switches, traps, doors, sensors, etc.

```json
{
  "id": "generator_1",
  "type": "interactable",
  "position": [400, 200],
  "trigger": {
    "on_interact": "activateGenerator",
    "on_destroyed": "explodeGenerator",
    "on_signal": "repairGenerator"
  }
}
```

---

## ⚡ Supported Triggers

### 🎮 Player-based

| Trigger          | Description                                  |
| ---------------- | -------------------------------------------- |
| `on_interact`    | Player presses interact key near the object. |
| `on_enter`       | Player enters a polygon area.                |
| `on_exit`        | Player leaves polygon.                       |
| `on_range`       | Player enters a defined range.               |
| `on_leave_range` | Player leaves that range.                    |
| `on_spawn`       | Player spawns in this area.                  |

---

### 💥 Combat-related

| Trigger        | Description                  |
| -------------- | ---------------------------- |
| `on_shot`      | Object is hit by projectile. |
| `on_damage`    | Object takes damage.         |
| `on_destroyed` | Object destroyed (HP ≤ 0).   |
| `on_kill`      | Object kills another entity. |

---

### ⚙️ Environmental / system

| Trigger             | Description                               |
| ------------------- | ----------------------------------------- |
| `on_timer`          | Fires after delay or periodically.        |
| `on_signal`         | Manual trigger from another object.       |
| `on_activate`       | Manually activated.                       |
| `on_deactivate`     | Manually deactivated.                     |
| `on_daytime`        | Triggered by game time (e.g., night/day). |
| `on_weather_change` | Fires when weather changes.               |
| `on_animation_end`  | When animation finishes.                  |

---

### 🧱 Collision / physics

| Trigger              | Description               |
| -------------------- | ------------------------- |
| `on_collision_enter` | Entity starts colliding.  |
| `on_collision_exit`  | Entity stops colliding.   |
| `on_push`            | Object physically moved.  |
| `on_overlap`         | Entity stays inside area. |

---

### 🧠 Logic / chaining

| Trigger           | Description                                       |
| ----------------- | ------------------------------------------------- |
| `on_trigger`      | Generic listener for external signal.             |
| `on_state_change` | Fires when state changes (visible, locked, etc.). |
| `on_variable`     | Triggered when a variable reaches a condition.    |
| `on_event`        | Called by global or story events.                 |
| `on_spawn_entity` | Entity spawned.                                   |
| `on_entity_death` | Entity dies.                                      |

---

## 🧩 Spawners

Define entity generation:

* **player**: Player spawn point (highest index = default)
* **wave**: Spawns multiple enemies in range
* **single**: Spawns a specific entity once

```json
"spawners": {
  "enemy_wave_1": {
    "type": "wave",
    "position": [300, 400],
    "spawn_range": 150,
    "entities": ["enemy_basic", "enemy_fast"]
  }
}
```

---

## 📜 Map Script Example (`home_script.lua`)

```lua
local M = {}

function M.openDoor(args, game)
    game:setTextureVisible("roof", false)
    game:playSound("door_open")
end

function M.toggleLight(args, game)
    game:setLightState("room_light", not game:getLightState("room_light"))
end

function M.spawnBoss(args, game)
    game:spawnEntity("boss_demon", args.position)
end

function M.activateGenerator(args, game)
    game:setVariable("power_on", true)
    game:sendSignal("lights_main", "on_activate")
end

return M
```

---

## 🔌 Signal System

* Any object can **emit a signal** with:

  ```lua
  game:sendSignal(target_id, event_name, args)
  ```
* The target object will execute its matching trigger function.
* Signals can carry optional data (`args`) for custom logic.

---

## 🧩 Example Flow

1. Player enters polygon → `roof.hide_area` triggers → roof fades out.
2. Player interacts with `light_switch` → calls `toggleLight()`.
3. Generator destroyed → `on_destroyed` calls `explodeGenerator()`.
4. Generator repaired → sends signal → `lights_main` runs `on_activate`.
5. Enemy death → triggers `spawnBoss()` from spawner.

---

## ✅ Summary

This format provides:

* Layered, polygon-based maps
* Integrated collision system
* Extensible trigger logic
* Modular script integration
* Signal-driven interactions
* Clear data separation between map logic and gameplay logic

**Camera and world boundaries are handled externally.**
