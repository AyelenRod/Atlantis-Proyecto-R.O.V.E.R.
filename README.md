# Misión Espacial

**Play it now:** https://atlantis-proyecto-rover-production.up.railway.app/

A space mission design game built in **Godot 4** for the **NASA Space Apps Challenge 2026** (*Space Mission Design Game*).
You run a space agency: plan the mission, build the spacecraft part by part, launch it, operate the arrival in a skill
minigame, and get a scored report explaining why your mission succeeded or failed.

Created by team **Polipops**, Universidad Politécnica de Chiapas.
Developed by **Ayelen Rodríguez, Montserrat Nolasco, Melissa Castañón, Jonathan Meza and Bruno Cruz**.

## How it plays

You walk through an orbital station. Each module is one phase of the mission and its airlock opens as you progress:

1. **Planning room** — pick the destination of your level and a route (cost, prep days, Δv, risk). What you don't spend on the route becomes the spacecraft budget.
2. **Laboratory** — research the destination, negotiate funds, assemble the ship from a catalog of 25 parts (structure, power, comms, computers, propulsion, thermal, instruments), test parts to lower their risk, and verify your propulsion covers the route. The ship must close on power, mass, budget and Δv.
3. **Launch room** — the ship travels on its own while fuel drops; transit events (course deviations, solar storms, micrometeoroids…) force you to choose between repairing or taking the risk.
4. **Operations room** — a skill minigame that depends on your destination: deploy a satellite in Earth orbit, land on the Moon and collect samples, land a rover on Mars, skim the solar corona, or dodge asteroids and scan Jupiter's moons.
5. **Results room** — a 0–100 score across eight checks (budget, power, mass, critical systems, reliability, transit, operation, science), stars, and a plain explanation of what worked and what failed.

## Levels

| Level | Destinations | Budget | Prep time | Information | Transit events |
|---|---|---|---|---|---|
| Easy | Earth orbit | Unlimited | Unlimited | Almost all visible | 1 |
| Medium | Moon or Mars | 930 M | 10 days | Partly hidden | 3 |
| Hard | Solar orbit or Jupiter | 750 M | 7 days | Mostly hidden | 5 |

Numbers are inspired by real missions: solar panels yield 43 % at Mars and 4 % at Jupiter, RTGs don't depend on the Sun,
Hohmann transfers, gravity assists, heat-shielded solar probes.

## Multiplayer (Medium and Hard)

- **Local co-op, 2–4 players, one screen.** The five phases are dealt among the players; each has an astronaut color and the game asks them to take the controls when their room opens. The final report shows each player's contribution.
- **LAN.** One player hosts, the others join by IP from the lobby; each plays their phases on their own device while the host syncs the mission state. (Desktop build only.)

Crew roles — Planner, Engineer, Finance and Astronaut — are assigned in the Planning room.

## Controls

WASD / arrows to move · **E** enter a room · **M** map · **Esc** leave a room · **F1** test mode (opens every airlock).
Each minigame shows its own controls before it starts.

## Run from source

Install Godot 4.3+, import `project.godot`, press F5. Web export and hosting steps (Railway / Vercel / itch.io) are in
[`deploy/README.md`](deploy/README.md).

## Tech

Godot 4 (GDScript) · code-drawn art (station, astronaut, consoles) · 3D planet backdrops with real textures in the minigames ·
ENet LAN multiplayer · HTML5 export served by a tiny Node server.
