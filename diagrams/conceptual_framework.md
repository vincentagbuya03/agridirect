# Figure 2.6.1 Conceptual Framework (AgrIDirect)

This framework mirrors the same structure as your sample image:
Inputs from major user groups flow into the AgrIDirect system, the system executes core processing, then generates operational and decision-support outputs.

## Mermaid Diagram

```mermaid
flowchart LR
    %% Actors (Inputs)
    C[CONSUMER\n- Product search and filtering\n- Order and pre-order requests\n- Delivery location and feedback]:::actor
    F[FARMER\n- Product listing and updates\n- Inventory and harvest availability\n- Farm location and fulfillment data]:::actor
    A[ADMIN OR CHIEF\n- Farmer verification decisions\n- Moderation and governance actions\n- Report and monitoring requests]:::actor

    %% Core system
    S[AGRIDIRECT SYSTEM\nFlutter Web and Mobile + Supabase Backend\nAuth, Marketplace, Orders, Messaging, Offline Cache]:::system

    %% Processing engine
    P((PROCESS)):::process
    P1[Validate and authenticate data]:::processStep
    P2[Store and synchronize profiles, products, and orders]:::processStep
    P3[Analyze demand, inventory, and geolocation context]:::processStep
    P4[Match supply with nearby customers and trigger notifications]:::processStep
    P5[Generate analytics-ready records and decision insights]:::processStep

    %% Output block
    O[OUTPUT\n- Real-time marketplace status\n- System-generated operational reports\n- Optimized delivery and pickup recommendations\n- Push notifications and alerts\n- Admin monitoring dashboard insights\n- Historical records for audit and evaluation]:::output

    %% Main directional flow (same conceptual pattern as sample)
    C -->|Consumer interaction data| S
    F -->|Farmer and inventory data| S
    A -->|Admin control and policy data| S

    S -->|Integrated platform events and records| P

    P --- P1
    P --- P2
    P --- P3
    P --- P4
    P --- P5

    P -->|Processed intelligence and actions| O

    %% Added feedback loop for continuous improvement
    O -. Feedback for optimization .-> S

    %% Visual styling similar to sample layout intent
    classDef actor fill:#f6f8fb,stroke:#3b5b7a,stroke-width:1.5px,color:#122033;
    classDef system fill:#e8f1ff,stroke:#2b6cb0,stroke-width:2px,color:#0f2740;
    classDef process fill:#fff7e6,stroke:#d69e2e,stroke-width:2px,color:#3a2a0a;
    classDef processStep fill:#fffdf7,stroke:#c8a24f,stroke-width:1px,color:#3a2a0a;
    classDef output fill:#edf9f0,stroke:#2f855a,stroke-width:2px,color:#113b27;
```
