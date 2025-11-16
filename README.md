🛡️ USA Treasury-y Knight
A gamified prototype to help people understand how federal spending impacts their communities.
📘 Overview

USA Treasury-y Knight is an interactive, educational game prototype created for the Challenge X Hackathon. It transforms real U.S. Treasury spending data into a fun, swipe-based quiz experience, making federal financial information more accessible, especially to younger audiences.

In this prototype, you play as the Treasure-y Knight, defending the heart of America’s tax dollars from a dragon that symbolizes threats to public funds.
The goal: answer questions correctly, avoid attacks, and protect taxpayer resources.

Built by Team Asyncode — a cross-continent collaboration between George Mason University (GMU) and Symbiosis University of Applied Sciences (SUAS).

👥 Team Asyncode
Name	University	Role
Tahsin Mahamud	George Mason University	Gameplay Programming, Godot Development, Data Integration
Sandhya Pal	SUAS	Data Research, API analysis, Presentation
Shreya Rai	SUAS	API Research, Question Design, Documentation

Our team name Asyncode reflects how we worked across time zones (U.S.–India) asynchronously but efficiently.

🎯 Project Goal

The purpose of the Local Impact Assistant prototype is to:

Increase financial transparency

Show how taxpayer dollars impact daily life

Make federal spending data easy and fun to understand

Provide an accessible gateway for people to explore government programs

Rather than showing raw numbers, we reframed the learning process inside a simple game.

🧠 Core Concept
📌 What the prototype demonstrates:

Real Treasury API data → Simplified into meaningful quiz questions

Gemini API → Generates two-option questions (stored in JSON)

Godot Engine → Mobile-friendly swipe gameplay

Game metaphor → Dragon steals funding, you protect it

This creates a narrative bridge between taxpayer money and public services, wrapped in fantasy aesthetics for engagement.

🕹️ Gameplay Features
✔ Swipe-based Answering

Swipe left or right to choose an answer.

✔ Real Spending Data

Questions reflect actual federal spending pulled from U.S. Treasury sources.

✔ Dragon Attack Logic

If answer is wrong → dragon attacks

If correct → player dodges or counters

Attack animations follow the question’s results

✔ Player & Dragon Health

Each wrong answer damages the player.
Each correct answer damages the dragon.

✔ Win/Lose Conditions

Victory: Dragon health reaches 0 → Player wins

Defeat: Player health reaches 0 → Loss message displays

✔ Intro Narrative

The game begins with a short story sequence explaining:

“The dragon has discovered the heart of our nation’s tax funds…”
Displayed with typewriter animation, two lines at a time.

🔌 Technical Features
🏗 Built With

Godot 4 (GDScript)

U.S. Treasury API

Gemini API

JSON cached question sets to avoid API limits

🔧 Major Systems

Swipe detection system

Attack queue & cooldown logic

Player/dragon health controllers

Procedural question loading

Typewriter effect for dialogue

Scene transitions and intro timer

Win/Loss animation state machine

🛠️ How the System Works
1. Data Collection (Treasury API)

We fetch key spending values and clean them for question generation.

2. Question Generation (Gemini API)

Gemini creates natural-language questions based on the spending data.
To avoid API rate limits, the questions are generated once and saved as:

/data/generated_questions_state_51.json

3. Game Loop

Godot loads the JSON → displays questions → handles swipe inputs → executes attack animations → checks win/loss.

🚧 Challenges & Solutions
❌ Gemini API rate limits

Fix: Generate questions once → save local JSON.

❌ Understanding Treasury API structure

Fix: Manual endpoint testing + filtering important fields.

❌ Time-zone delays

Fix: Asynchronous work, modular tasks, and version control.

❌ Building a polished prototype quickly

Fix: Prioritized core mechanics + simple but effective design.

📂 Repository Structure

Here is a suggested layout for your GitHub repo:

USA-Treasury-Knight/
│
├── /Scenes/
│   ├── intro.tscn
│   ├── game.tscn
│   ├── start_button.tscn
│   └── player.tscn
│
├── /Scripts/
│   ├── question_generator.gd
│   ├── dragon_head.gd
│   ├── health_player.gd
│   ├── dialogue.gd
│   ├── final_message.gd
│   └── swipe.gd
│
├── /data/
│   └── generated_questions_state_51.json
│
├── /img/
│   ├── Cave.png
│   ├── scroll.png
│   ├── dragon_head.png
│   └── heroes_tileset.png
│
├── README.md
└── LICENSE

🚀 How to Run
1. Clone the repository
git clone https://github.com/YOUR_USERNAME/USA-Treasury-Knight.git
