# AgriDirect System Architecture

## System Mapping

```mermaid
graph TB
    INTERNET["🌍 Internet"]

    subgraph APP["AgriDirect Platform"]
        AGRIDIRECT["📱 AgriDirect App<br/>Web & Mobile"]
    end

    subgraph USERS["Users"]
        CUSTOMER["👥 Customer<br/>Buyer"]
        FARMER["👨‍🌾 Farmer<br/>Seller"]
        ADMIN["⚙️ Admin<br/>Manager"]
    end

    subgraph SERVER["🖥️ Server Backend"]
        DB["📊 Database<br/>PostgreSQL"]
        AUTH["🔐 Authentication"]
        STORAGE["📁 Storage<br/>Files & Images"]
    end

    %% Main Flow
    INTERNET --> AGRIDIRECT

    AGRIDIRECT --> CUSTOMER
    AGRIDIRECT --> FARMER
    AGRIDIRECT --> ADMIN

    CUSTOMER --> APP_LOGIC["Customer Services<br/>Marketplace, Orders"]
    FARMER --> APP_LOGIC2["Farmer Services<br/>Products, Sales"]
    ADMIN --> APP_LOGIC3["Admin Services<br/>Management"]

    APP_LOGIC --> SERVER
    APP_LOGIC2 --> SERVER
    APP_LOGIC3 --> SERVER

    SERVER --> AUTH
    SERVER --> DB
    SERVER --> STORAGE

    %% Styling
    classDef internet fill:#b3e5fc,stroke:#0277bd,color:#000,stroke-width:3px
    classDef app fill:#c8e6c9,stroke:#2e7d32,color:#000,stroke-width:3px
    classDef users fill:#ffe0b2,stroke:#e65100,color:#000,stroke-width:3px
    classDef server fill:#f8bbd0,stroke:#c2185b,color:#000,stroke-width:3px
    classDef services fill:#e1bee7,stroke:#6a1b9a,color:#000,stroke-width:3px

    class INTERNET internet
    class AGRIDIRECT,APP app
    class CUSTOMER,FARMER,ADMIN users
    class DB,AUTH,STORAGE,SERVER server
    class APP_LOGIC,APP_LOGIC2,APP_LOGIC3 services
```

## Overview

| Component | Description |
|-----------|------------|
| **Internet** | Global connectivity |
| **AgriDirect** | Web & Mobile application |
| **Customer** | Buyers - Browse & purchase products |
| **Farmer** | Sellers - List & manage products |
| **Admin** | Managers - Oversee platform |
| **Server** | Backend infrastructure (Database, Auth, Storage) |

## Technology Stack

- **Frontend**: Flutter (Web & Mobile)
- **Backend**: Supabase (PostgreSQL)
- **Auth**: Email/OTP + Google OAuth
- **Storage**: File buckets for images

---

*Last Updated: 2026-03-21*
