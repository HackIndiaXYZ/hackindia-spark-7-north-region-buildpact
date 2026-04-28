# hackindia-spark-7-north-region-buildpact
Hackathon team repository for BuildPact - [hackindia-team:hackindia-spark-7-north-region:buildpact]
# 🚀 BuildPact — AI-Powered Software Delivery with Smart Contract Escrow

> Turn ideas into production-ready software — with automated negotiation, AI generation, testing, and trustless payments.

---

## 🧠 Problem

Building software today is broken:

- Clients don’t know how to define requirements  
- Developers misinterpret expectations  
- Scope creep kills timelines  
- Payments rely on trust → disputes happen  
- No transparency during development  

---

## 💡 Solution

**BuildPact** solves this with an end-to-end automated pipeline:

- 📋 AI-driven requirement negotiation (SRS builder)  
- 🧠 Smart contradiction detection & confidence scoring  
- ⚙️ Automated code generation using a template vault  
- 🧪 Multi-layer testing (functional + security + performance)  
- 🔗 Smart contract escrow (Polygon Amoy)  
- 📊 Real-time “Build Theatre” dashboard  

👉 Result: **Transparent, trustless, and automated software delivery**

Client → SRS Engine → AI Processing → Vault System → Code Generation
↓
Smart Contract Escrow (Polygon)
↓
Testing Pipeline → Dashboard → Delivery

## 🏗️ System Architecture


---

## ⚡ Key Features

### 🧾 AI SRS Negotiation Engine
- 250+ structured decision-tree questions  
- Converts user answers → production-ready SRS  
- Claude fallback for custom inputs  

### 🧠 Intelligence Layer
- Contradiction detection  
- Confidence scoring (0–100)  
- Regulatory compliance flags  
- Domain disambiguation  

### 🧱 Component Vault System
- Pre-built reusable components  
- 3-tier architecture:
  - Iron Core (logic)  
  - Skeleton (structure)  
  - Surface Skin (unique UI)  

### 🔗 Smart Contract Escrow
- Built on Polygon Amoy Testnet  
- Milestone-based payments  
- Cancellation logic + recovery wallets  
- Trustless execution  

### 🧪 Automated Testing Pipeline
- Jest-based functional tests  
- OWASP security checks  
- Accessibility audit  
- Load testing  

### 📊 Build Theatre Dashboard
- Live file generation  
- Real-time test results  
- Escrow tracking  
- Visual progress system  

### 📦 Delivery Engine
- Full codebase ZIP  
- Documentation auto-generated  
- On-chain verification hash  

---

## 🛠️ Tech Stack

### Frontend
- React + Vite + Tailwind CSS  

### Backend
- FastAPI (Python)  
- Claude API + Gemini API + ChatGPT  
- Firebase Auth + Firestore  

### Blockchain
- Solidity + Hardhat  
- Polygon Amoy Testnet  
- ethers.js / web3.py  

### AI System
- Claude (reasoning + generation)  
- Gemini (vision + search)  

---

## ⚙️ Setup Guide

### 📦 1. Clone the Repository


git clone 
cd buildpact

cd backend
pip install -r requirements.txt

ANTHROPIC_API_KEY=your_key
GEMINI_API_KEY=your_key
FIREBASE_SERVICE_ACCOUNT_PATH=./firebase.json
PLATFORM_WALLET_PRIVATE_KEY=your_wallet_key
AMOY_RPC_URL=https://rpc-amoy.polygon.technology

uvicorn main:app --reload
cd frontend
npm install
npm run dev


---
4. Firebase Setup
Create a Firebase project
Enable:
Authentication (Google)
Firestore
Storage
Replace config in frontend

🦊  Wallet Setup
Install MetaMask
Add Polygon Amoy network
Get test POL tokens

▶️  Run the Project
Open frontend (http://localhost:5173)
Login with Google
Start demo flow

🎬 Demo Flow (For Judges)
User answers pre-qualification questions
AI builds structured SRS
Contradictions resolved
Pricing generated
Smart contract deployed
Build starts live:
Code generation
Testing
Payment release

Final delivery package generated
🧩 Unique Innovations
❌ No fine-tuned AI → replaced with Vault System
⚡ 70% fewer API calls
🔒 Trustless payments via smart contracts
🧠 AI + deterministic system hybrid
🎯 Built for zero-budget scalability
🚧 Limitations
Simplified testing pipeline (demo mode)
Limited question bank (~250 vs 5000 planned)
No production deployment automation yet
Testnet blockchain only
🔮 Future Scope
DAO governance
Template marketplace
Mobile app
Enterprise API
AI model optimization

