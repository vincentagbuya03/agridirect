# 🌐 AgriDirect Network Topology & Infrastructure

This document outlines the real network architecture and data flow for the AgriDirect ecosystem. It represents the high-fidelity integration between the mobile client, cloud services, and external API providers.

## 🖼️ Premium Network Architecture Visual
![AgriDirect Network Topology](file:///c:/Users/Nick%20Vincent%20Agbuya/Documents/Flutter%20Project/agridirect/assets/diagrams/network_topology_premium.png)

## 🏗️ High-Level Network Diagram ```mermaid
graph TD
    %% Define Styles
    classDef actor fill:#334155,stroke:#1e293b,stroke-width:2px,color:#fff;
    classDef mobile fill:#16A34A,stroke:#15803D,stroke-width:2px,color:#fff;
    classDef web fill:#0EA5E9,stroke:#0284C7,stroke-width:2px,color:#fff;
    classDef cloud fill:#2563EB,stroke:#1D4ED8,stroke-width:2px,color:#fff;
    classDef external fill:#F59E0B,stroke:#D97706,stroke-width:2px,color:#fff;
    classDef system fill:#4F46E5,stroke:#4338CA,stroke-width:2px,color:#fff;
    classDef storage fill:#6366F1,stroke:#4F46E5,stroke-width:2px,color:#fff;
    classDef internet fill:#F8FAFC,stroke:#CBD5E1,stroke-width:2px,color:#64748B,stroke-dasharray: 2 2;
    classDef hosting fill:#EC4899,stroke:#DB2777,stroke-width:2px,color:#fff;

    subgraph UserRoles ["👥 User Personas"]
        Farmer["👨‍🌾 Farmer<br/>(Producer)"]
        Consumer["🛒 Consumer<br/>(Buyer)"]
        Admin["⚖️ Administrator<br/>(Moderator)"]
    end

    subgraph ClientLayer ["📱💻 Client Side (Local Device)"]
        direction LR
        MobileApp["📱 AgriDirect Mobile<br/>(Flutter iOS/Android)"]
        WebApp["💻 AgriDirect Web<br/>(Browser/Admin Panel)"]
        
        LocalCache[("📦 Hive Local Storage<br/>(Offline Cache)")]
        MLKit["🧠 Google ML Kit<br/>(On-Device AI)"]
        
        MobileApp --- LocalCache
        MobileApp --- MLKit
    end

    subgraph NetworkLayer ["🌐 Communication Bridge"]
        Internet(("🔒 The Internet<br/>(Secure Gateway)"))
    end

    subgraph BackendLayer ["☁️ Supabase Cloud (The System)"]
        direction TB
        Auth["🔑 Supabase Auth<br/>(Identity)"]
        DB[("🐘 PostgreSQL DB<br/>(Relational)")]
        Store["📁 Supabase Storage<br/>(Media)"]
        Edge["⚡ Edge Functions<br/>(Business Logic)"]
    end

    subgraph ExternalServices ["🔗 External API Zone"]
        WeatherAPI["⛅ OpenWeather API"]
        OSMMaps["🗺️ OpenStreetMap / CartoDB"]
        FCM["🔔 Firebase Notifications"]
    end

    subgraph WebHosting ["▲ Vercel Hosting"]
        WebAssets["Flutter Web Assets<br/>(CDN Cache)"]
    end

    %% Network Connections
    Farmer & Consumer & Admin ==> MobileApp & WebApp
    
    %% Request Flows
    MobileApp & WebApp <== "TLS 1.3 Encryption" ==> Internet
    Internet <==> Edge
    Edge <==> Auth & DB & Store
    
    %% Web Hosting Connection
    WebApp -. "Asset Delivery" .-> WebAssets
    WebAssets -. "Hosted On" .-> Internet

    %% External Data Flow
    Edge <==> WeatherAPI
    Edge <==> OSMMaps
    Edge <==> FCM

    %% Assign Classes
    class Farmer,Consumer,Admin actor;
    class MobileApp,LocalCache,MLKit mobile;
    class WebApp web;
    class Auth,DB,Store,Edge system;
    class WeatherAPI,OSMMaps,FCM external;
    class Internet internet;
    class WebAssets hosting;
```

## 🛰️ Network Infrastructure Components

### 1. User Roles & Access
*   **Farmer (Producer)**: Accesses the system primarily via **Mobile** for farm management, product listing, and real-time alerts. Uses offline-first features for remote locations.
*   **Consumer (Buyer)**: Accesses via **Mobile or Web** to browse the marketplace, track orders, and interact with the community.
*   **Administrator (Moderator)**: Primarily uses the **Web/Admin Panel** for user verification, marketplace moderation, and system-wide analytics.

### 2. Multi-Platform Support (The Edge)
*   **AgriDirect Mobile**: Built with Flutter for high-performance interaction on iOS and Android. Utilizes **Hive** for offline sync and **ML Kit** for on-device identity verification (Face ID).
*   **AgriDirect Web**: A Flutter Web application that runs in modern browsers. It is lightweight and provides a desktop-class experience for admins and consumers.

### 3. Web Hosting & CDN (Vercel)
*   **Deployment**: The Web application is compiled into optimized static assets and deployed to **Vercel** ([agridirect-app.vercel.app](https://agridirect-app.vercel.app)). 
*   **Role**: Vercel acts as the **Static Asset Provider**, serving the Flutter Web files via its global CDN for maximum speed. It does not handle database logic; it simply delivers the frontend to the user's browser.

### 4. The Internet Gateway
*   **Public Connectivity**: Acts as the encrypted bridge between the local device and cloud services.
*   **Encrypted Traffic**: All data transmitted over the internet is secured using **TLS 1.3** to protect user data and financial transactions.

### 5. Supabase Cloud (The Core System)
*   Supabase acts as the primary **Backend-as-a-Service (BaaS)** provider, replacing traditional monolithic server setups.
*   **PostgreSQL**: Handles all relational data with strict Row Level Security (RLS).
*   **Auth**: Secure PKCE flow for mobile and standard JWT for web sessions.
*   **Edge Functions**: Serverless logic that executes business rules and coordinates with external APIs.

### 6. External Services & Reliability
*   **Firebase (FCM)**: The backbone for push notifications across both mobile and web clients.
*   **OpenStreetMap & Weather**: Geodata services providing farm-specific weather forecasting and high-definition mapping tiles. (CartoDB Voyager style).ther**: Geodata services providing farm-specific weather forecasting and marketplace logistics.

---
> [!IMPORTANT]
> **System Reliability**: The architecture is designed to be **fault-tolerant**. If the central system is unreachable, the **Mobile Client** falls back to **Hive Local Storage**, allowing farmers to continue recording data which automatically syncs once connectivity is restored.
