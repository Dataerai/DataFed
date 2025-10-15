# DataFed Architecture Reference

This document provides detailed architectural diagrams and explanations of the DataFed system.

## Table of Contents
1. [System Overview](#system-overview)
2. [Component Architecture](#component-architecture)
3. [Data Flow Diagrams](#data-flow-diagrams)
4. [Communication Patterns](#communication-patterns)
5. [Database Schema](#database-schema)
6. [Deployment Topologies](#deployment-topologies)

---

## System Overview

### High-Level Architecture

```
                              ┌─────────────────────────────┐
                              │         Users               │
                              └──────────┬──────────────────┘
                                         │
                    ┌────────────────────┼────────────────────┐
                    │                    │                    │
                    ▼                    ▼                    ▼
            ┌───────────────┐    ┌──────────────┐    ┌──────────────┐
            │   Web Portal  │    │     CLI      │    │  Python API  │
            │   (Browser)   │    │  (Terminal)  │    │  (Scripts)   │
            └───────┬───────┘    └──────┬───────┘    └──────┬───────┘
                    │                   │                    │
                    └───────────────────┼────────────────────┘
                                        │
                                        ▼
                            ┌───────────────────────┐
                            │    Web Service        │
                            │    (Node.js/Express)  │
                            │                       │
                            │  ┌─────────────────┐ │
                            │  │ Authentication  │ │
                            │  │ (Globus OAuth)  │ │
                            │  └─────────────────┘ │
                            │  ┌─────────────────┐ │
                            │  │  API Proxy      │ │
                            │  │  (ZeroMQ)       │ │
                            │  └─────────────────┘ │
                            └──────────┬────────────┘
                                       │ ZeroMQ
                                       │ (protobuf)
                                       ▼
                            ┌───────────────────────┐
                            │   Core Service        │
                            │   (C++)               │
                            │                       │
                            │  ┌─────────────────┐ │
                            │  │ Client Workers  │ │
                            │  │ (Request Proc)  │ │
                            │  └─────────────────┘ │
                            │  ┌─────────────────┐ │
                            │  │ Task Workers    │ │
                            │  │ (Background)    │ │
                            │  └─────────────────┘ │
                            │  ┌─────────────────┐ │
                            │  │ Database API    │ │
                            │  └─────────────────┘ │
                            │  ┌─────────────────┐ │
                            │  │ Globus API      │ │
                            │  └─────────────────┘ │
                            └──┬─────────────┬──────┘
                               │             │
                 HTTP/REST     │             │ ZeroMQ
                               │             │
                               ▼             ▼
                    ┌──────────────┐  ┌──────────────────┐
                    │   ArangoDB   │  │ Repo Service(s)  │
                    │   Database   │  │     (C++)        │
                    │              │  │                  │
                    │ ┌──────────┐ │  │ ┌──────────────┐│
                    │ │   Foxx   │ │  │ │ GridFTP DSI  ││
                    │ │   App    │ │  │ └──────────────┘│
                    │ └──────────┘ │  │ ┌──────────────┐│
                    │              │  │ │Globus Client ││
                    │ Collections: │  │ └──────────────┘│
                    │  • Users     │  └────────┬─────────┘
                    │  • Data      │           │
                    │  • Projects  │           │ GridFTP
                    │  • Tasks     │           │
                    └──────────────┘           ▼
                                        ┌──────────────┐
                                        │   Storage    │
                                        │  (File Sys)  │
                                        └──────────────┘
```

---

## Component Architecture

### Core Service Internal Architecture

```
┌─────────────────────────────────────────────────────────────────┐
│                         Core Service                            │
│                                                                 │
│  ┌──────────────────────────────────────────────────────────┐  │
│  │                    Main Server Thread                     │  │
│  │                                                           │  │
│  │  ┌─────────────┐         ┌─────────────┐                │  │
│  │  │ZMQ ROUTER   │◄───────►│ ZMQ DEALER  │                │  │
│  │  │(Clients)    │         │(Repos)      │                │  │
│  │  └──────┬──────┘         └──────┬──────┘                │  │
│  │         │                       │                        │  │
│  └─────────┼───────────────────────┼────────────────────────┘  │
│            │                       │                           │
│            │ Distribute            │ Forward                   │
│            │                       │                           │
│  ┌─────────▼───────────────────────▼────────────────────────┐  │
│  │                 Internal ZMQ Proxy                       │  │
│  │                    (Load Balancer)                       │  │
│  └─────────┬──────────────────────────────────────┬─────────┘  │
│            │                                      │            │
│    ┌───────▼────────┐                    ┌────────▼─────────┐  │
│    │ Client Worker  │                    │  Task Worker     │  │
│    │    Thread      │                    │    Thread        │  │
│    │                │                    │                  │  │
│    │ ┌────────────┐ │                    │ ┌──────────────┐ │  │
│    │ │Request Proc│ │                    │ │Task Manager  │ │  │
│    │ └────────────┘ │                    │ └──────────────┘ │  │
│    │ ┌────────────┐ │                    │ ┌──────────────┐ │  │
│    │ │Auth/Authz  │ │                    │ │Xfr Monitor   │ │  │
│    │ └────────────┘ │                    │ └──────────────┘ │  │
│    │ ┌────────────┐ │                    │ ┌──────────────┐ │  │
│    │ │Validation  │ │                    │ │Cleanup Tasks │ │  │
│    │ └────────────┘ │                    │ └──────────────┘ │  │
│    └────┬───────────┘                    └──────────────────┘  │
│         │                                                       │
│         │ Uses                                                  │
│         ▼                                                       │
│  ┌──────────────────────────────────────────────────────────┐  │
│  │                   Shared Components                       │  │
│  │                                                           │  │
│  │  ┌──────────────┐  ┌──────────────┐  ┌────────────────┐ │  │
│  │  │ DatabaseAPI  │  │  GlobusAPI   │  │ Configuration  │ │  │
│  │  │              │  │              │  │                │ │  │
│  │  │• Query DB    │  │• Auth tokens │  │• Settings      │ │  │
│  │  │• Update DB   │  │• Start xfr   │  │• Credentials   │ │  │
│  │  │• Foxx calls  │  │• Check status│  │• Keys          │ │  │
│  │  └──────────────┘  └──────────────┘  └────────────────┘ │  │
│  └──────────────────────────────────────────────────────────┘  │
└─────────────────────────────────────────────────────────────────┘
```

### Web Service Architecture

```
┌──────────────────────────────────────────────────────────────┐
│                      Web Service (Node.js)                   │
│                                                              │
│  ┌────────────────────────────────────────────────────────┐ │
│  │                    Express.js App                       │ │
│  │                                                         │ │
│  │  ┌──────────────────────────────────────────────────┐  │ │
│  │  │              Middleware Stack                     │  │ │
│  │  │                                                   │  │ │
│  │  │  1. Helmet (Security headers)                     │  │ │
│  │  │  2. Cookie Parser                                 │  │ │
│  │  │  3. Session Management (express-session)          │  │ │
│  │  │  4. Body Parser (JSON/text)                       │  │ │
│  │  │  5. Static File Server                            │  │ │
│  │  └──────────────────────────────────────────────────┘  │ │
│  │                                                         │ │
│  │  ┌──────────────────────────────────────────────────┐  │ │
│  │  │                  Route Handlers                   │  │ │
│  │  │                                                   │  │ │
│  │  │  UI Routes (/ui/*)                                │  │ │
│  │  │  ├─ /ui/welcome    → Welcome page                 │  │ │
│  │  │  ├─ /ui/login      → OAuth redirect               │  │ │
│  │  │  ├─ /ui/authn      → OAuth callback               │  │ │
│  │  │  ├─ /ui/register   → User registration            │  │ │
│  │  │  ├─ /ui/main       → Main application             │  │ │
│  │  │  └─ /ui/logout     → Logout                       │  │ │
│  │  │                                                   │  │ │
│  │  │  API Routes (/api/*)                              │  │ │
│  │  │  ├─ /api/dat/*     → Data operations              │  │ │
│  │  │  ├─ /api/col/*     → Collection operations        │  │ │
│  │  │  ├─ /api/prj/*     → Project operations           │  │ │
│  │  │  ├─ /api/usr/*     → User operations              │  │ │
│  │  │  └─ /api/*/...     → Other APIs                   │  │ │
│  │  └──────────────────────────────────────────────────┘  │ │
│  │                                                         │ │
│  │  ┌──────────────────────────────────────────────────┐  │ │
│  │  │             Service Modules                       │  │ │
│  │  │                                                   │  │ │
│  │  │  ┌──────────────────┐  ┌─────────────────────┐   │  │ │
│  │  │  │ Authentication   │  │   ZMQ Client        │   │  │ │
│  │  │  │                  │  │                     │   │  │ │
│  │  │  │• TokenHandler    │  │• DEALER socket      │   │  │ │
│  │  │  │• ConsentHandler  │  │• Message encoding   │   │  │ │
│  │  │  │• OAuth flow      │  │• Context mgmt       │   │  │ │
│  │  │  └──────────────────┘  └─────────────────────┘   │  │ │
│  │  └──────────────────────────────────────────────────┘  │ │
│  └─────────────────────────────────────────────────────────┘ │
│                                                              │
│  ┌────────────────────────────────────────────────────────┐ │
│  │                 Frontend (Static Files)                │ │
│  │                                                        │ │
│  │  JavaScript:                  CSS/Assets:             │ │
│  │  • main.js                    • style.css             │ │
│  │  • api.js                     • jquery-ui themes      │ │
│  │  • dialogs.js                 • images/icons          │ │
│  │  • util.js                                            │ │
│  │  • components/                Templates (ECT):        │ │
│  │    ├─ endpoint-browse/        • index.ect             │ │
│  │    ├─ provenance/             • main.ect              │ │
│  │    └─ transfer/               • register.ect          │ │
│  └────────────────────────────────────────────────────────┘ │
└──────────────────────────────────────────────────────────────┘
```

### Repository Service Architecture

```
┌───────────────────────────────────────────────────────┐
│               Repository Service (C++)                │
│                                                       │
│  ┌─────────────────────────────────────────────────┐ │
│  │              Main Server Thread                  │ │
│  │                                                  │ │
│  │  ┌────────────────┐    ┌────────────────────┐   │ │
│  │  │  ZMQ DEALER    │◄──►│  Config Manager    │   │ │
│  │  │  (to Core)     │    │                    │   │ │
│  │  └────────┬───────┘    └────────────────────┘   │ │
│  │           │                                      │ │
│  └───────────┼──────────────────────────────────────┘ │
│              │                                        │
│              │ Distribute                             │
│              ▼                                        │
│  ┌───────────────────────────────────────────────┐   │
│  │          Request Worker Threads               │   │
│  │                                               │   │
│  │  ┌─────────────────────────────────────────┐ │   │
│  │  │        Transfer Management              │ │   │
│  │  │                                         │ │   │
│  │  │  • Validate allocation                  │ │   │
│  │  │  • Check permissions                    │ │   │
│  │  │  • Initiate Globus transfer             │ │   │
│  │  │  • Monitor status                       │ │   │
│  │  │  • Update Core on completion            │ │   │
│  │  └─────────────────────────────────────────┘ │   │
│  │                                               │   │
│  │  ┌─────────────────────────────────────────┐ │   │
│  │  │        Storage Management               │ │   │
│  │  │                                         │ │   │
│  │  │  • Allocation tracking                  │ │   │
│  │  │  • Quota enforcement                    │ │   │
│  │  │  • Path mapping                         │ │   │
│  │  │  • File verification                    │ │   │
│  │  └─────────────────────────────────────────┘ │   │
│  └───────────────────────────────────────────────┘   │
│                      │                                │
│                      │ Interfaces with                │
│                      ▼                                │
│  ┌───────────────────────────────────────────────┐   │
│  │          Globus Components                    │   │
│  │                                               │   │
│  │  ┌──────────────┐        ┌─────────────────┐ │   │
│  │  │ GridFTP DSI  │        │ Globus Transfer │ │   │
│  │  │ (authz)      │◄──────►│ Client          │ │   │
│  │  └──────┬───────┘        └────────┬────────┘ │   │
│  └─────────┼─────────────────────────┼──────────┘   │
│            │                         │              │
│            ▼                         ▼              │
│     ┌─────────────┐           ┌─────────────┐      │
│     │GridFTP      │           │Globus Cloud │      │
│     │Server       │◄─────────►│Service      │      │
│     └─────┬───────┘           └─────────────┘      │
│           │                                         │
│           ▼                                         │
│     ┌─────────────┐                                 │
│     │ Local       │                                 │
│     │ Storage     │                                 │
│     └─────────────┘                                 │
└───────────────────────────────────────────────────────┘
```

---

## Data Flow Diagrams

### User Authentication Flow

```
┌─────┐                ┌─────┐              ┌──────┐           ┌─────┐
│User │                │ Web │              │Globus│           │Core │
└──┬──┘                └──┬──┘              └───┬──┘           └──┬──┘
   │                      │                     │                 │
   │  1. Click "Login"    │                     │                 │
   ├─────────────────────►│                     │                 │
   │                      │                     │                 │
   │  2. Redirect to      │                     │                 │
   │     Globus Auth      │                     │                 │
   │◄─────────────────────┤                     │                 │
   │                      │                     │                 │
   │  3. Login with       │                     │                 │
   │     credentials      │                     │                 │
   ├──────────────────────┼────────────────────►│                 │
   │                      │                     │                 │
   │  4. Auth code        │                     │                 │
   │◄─────────────────────┼─────────────────────┤                 │
   │                      │                     │                 │
   │  5. Redirect to      │                     │                 │
   │     /ui/authn        │                     │                 │
   ├─────────────────────►│                     │                 │
   │                      │                     │                 │
   │                      │  6. Exchange code   │                 │
   │                      │     for tokens      │                 │
   │                      ├────────────────────►│                 │
   │                      │                     │                 │
   │                      │  7. Access token    │                 │
   │                      │     + refresh token │                 │
   │                      │◄────────────────────┤                 │
   │                      │                     │                 │
   │                      │  8. Verify user     │                 │
   │                      │     (UserFindByUUIDs)                 │
   │                      ├───────────────────────────────────────►│
   │                      │                     │                 │
   │                      │  9. User data       │                 │
   │                      │◄───────────────────────────────────────┤
   │                      │                     │                 │
   │                      │ 10. Store tokens    │                 │
   │                      │     (UserSetAccessToken)              │
   │                      ├───────────────────────────────────────►│
   │                      │                     │                 │
   │                      │ 11. Create session  │                 │
   │                      │     (store uid)     │                 │
   │  12. Redirect        │                     │                 │
   │      to /ui/main     │                     │                 │
   │◄─────────────────────┤                     │                 │
   │                      │                     │                 │
```

### Data Record Creation Flow

```
┌─────┐     ┌─────┐     ┌──────┐     ┌─────┐     ┌──────────┐
│User │     │ Web │     │ Core │     │Foxx │     │ArangoDB  │
└──┬──┘     └──┬──┘     └───┬──┘     └──┬──┘     └────┬─────┘
   │           │            │           │             │
   │ POST      │            │           │             │
   │ /api/dat/ │            │           │             │
   │ create    │            │           │             │
   ├──────────►│            │           │             │
   │           │            │           │             │
   │           │RecordCreate│           │             │
   │           │Request     │           │             │
   │           │(protobuf)  │           │             │
   │           ├───────────►│           │             │
   │           │            │           │             │
   │           │            │ Validate  │             │
   │           │            │ session   │             │
   │           │            │           │             │
   │           │            │ Check     │             │
   │           │            │ perms     │             │
   │           │            │           │             │
   │           │            │ POST      │             │
   │           │            │ /api/data/│             │
   │           │            │ create    │             │
   │           │            ├──────────►│             │
   │           │            │           │             │
   │           │            │           │ INSERT INTO │
   │           │            │           │ d {...}     │
   │           │            │           ├────────────►│
   │           │            │           │             │
   │           │            │           │ New doc     │
   │           │            │           │◄────────────┤
   │           │            │           │             │
   │           │            │ JSON      │             │
   │           │            │ response  │             │
   │           │            │◄──────────┤             │
   │           │            │           │             │
   │           │RecordCreate│           │             │
   │           │Reply       │           │             │
   │           │(protobuf)  │           │             │
   │           │◄───────────┤           │             │
   │           │            │           │             │
   │ JSON      │            │           │             │
   │ response  │            │           │             │
   │◄──────────┤            │           │             │
   │           │            │           │             │
```

### Data Transfer Flow (PUT)

```
┌────┐  ┌───┐  ┌────┐  ┌────┐  ┌────┐  ┌──────┐  ┌───────┐
│User│  │Web│  │Core│  │Repo│  │Foxx│  │Globus│  │Storage│
└─┬──┘  └─┬─┘  └─┬──┘  └─┬──┘  └─┬──┘  └───┬──┘  └───┬───┘
  │       │      │       │       │         │         │
  │DataPut│      │       │       │         │         │
  │Request│      │       │       │         │         │
  ├──────►│      │       │       │         │         │
  │       │      │       │       │         │         │
  │       │DataPut       │       │         │         │
  │       │Req   │       │       │         │         │
  │       ├─────►│       │       │         │         │
  │       │      │       │       │         │         │
  │       │      │Create │       │         │         │
  │       │      │Task   │       │         │         │
  │       │      ├──────────────►│         │         │
  │       │      │       │       │ INSERT  │         │
  │       │      │       │       │ task    │         │
  │       │      │       │       │         │         │
  │       │      │Get    │       │         │         │
  │       │      │Globus │       │         │         │
  │       │      │token  │       │         │         │
  │       │      │       │       │         │         │
  │       │      │XferReq│       │         │         │
  │       │      ├──────►│       │         │         │
  │       │      │       │       │         │         │
  │       │      │       │Initiate        │         │
  │       │      │       │Transfer│        │         │
  │       │      │       ├────────────────►│         │
  │       │      │       │       │         │         │
  │       │      │       │       │         │GridFTP  │
  │       │      │       │       │         │Transfer │
  │       │      │       │       │         ├────────►│
  │       │      │       │       │         │         │
  │       │      │       │Poll   │         │         │
  │       │      │       │Status │         │         │
  │       │      │       ├────────────────►│         │
  │       │      │       │       │         │         │
  │       │      │       │Status │         │         │
  │       │      │       │(active)        │         │
  │       │      │       │◄────────────────┤         │
  │       │      │       │       │         │         │
  │       │      │       │ ...   │         │         │
  │       │      │       │       │         │         │
  │       │      │       │Poll   │         │         │
  │       │      │       ├────────────────►│         │
  │       │      │       │       │         │         │
  │       │      │       │Status │         │         │
  │       │      │       │(done) │         │         │
  │       │      │       │◄────────────────┤         │
  │       │      │       │       │         │         │
  │       │      │       │Update │         │         │
  │       │      │       │Task   │         │         │
  │       │      │       ├──────────────────────────►│
  │       │      │       │       │         │         │
  │       │      │Update │       │ UPDATE  │         │
  │       │      │Record │       │ d SET   │         │
  │       │      │       │       │ size... │         │
  │       │      ├──────────────►│         │         │
  │       │      │       │       │         │         │
  │       │TaskID│       │       │         │         │
  │       │◄─────┤       │       │         │         │
  │       │      │       │       │         │         │
  │TaskID │      │       │       │         │         │
  │◄──────┤      │       │       │         │         │
  │       │      │       │       │         │         │
```

---

## Communication Patterns

### ZeroMQ Message Structure

```
┌────────────────────────────────────────────────────────┐
│                    ZMQ Message Frame                   │
├────────────────────────────────────────────────────────┤
│                                                        │
│  Frame 0: Delimiter "BEGIN_DATAFED"                    │
│           (15 bytes string)                            │
│                                                        │
├────────────────────────────────────────────────────────┤
│                                                        │
│  Frame 1: Route Count                                  │
│           (4 bytes, big-endian uint32)                 │
│           Used for router-dealer chains                │
│                                                        │
├────────────────────────────────────────────────────────┤
│                                                        │
│  Frame 2: Delimiter (empty frame)                      │
│                                                        │
├────────────────────────────────────────────────────────┤
│                                                        │
│  Frame 3: Correlation ID                               │
│           (UUID v4 string)                             │
│           For request/reply matching and logging       │
│                                                        │
├────────────────────────────────────────────────────────┤
│                                                        │
│  Frame 4: Encryption Key ID                            │
│           (string, "no_key" for unencrypted)           │
│                                                        │
├────────────────────────────────────────────────────────┤
│                                                        │
│  Frame 5: Client ID                                    │
│           (string, user ID or service ID)              │
│                                                        │
├────────────────────────────────────────────────────────┤
│                                                        │
│  Frame 6: Message Header (8 bytes)                     │
│           ┌─────────────────────────────────────┐      │
│           │ Bytes 0-3: Message Length (uint32)  │      │
│           │ Byte 4:    Protocol ID (uint8)      │      │
│           │ Byte 5:    Message ID (uint8)       │      │
│           │ Bytes 6-7: Context ID (uint16)      │      │
│           └─────────────────────────────────────┘      │
│                                                        │
├────────────────────────────────────────────────────────┤
│                                                        │
│  Frame 7: Protobuf Message Payload                     │
│           (Variable length binary data)                │
│           Serialized protocol buffer message           │
│                                                        │
└────────────────────────────────────────────────────────┘
```

### Socket Patterns

#### DEALER-ROUTER (Client to Core)

```
┌──────────────┐                    ┌──────────────┐
│   Client     │                    │     Core     │
│   (DEALER)   │                    │   (ROUTER)   │
│              │                    │              │
│  Socket ID:  │                    │ Auto-assigns │
│  Random      │                    │ socket IDs   │
│              │                    │              │
│  Send:       │                    │ Receive:     │
│  [msg]       │───────────────────►│ [id][msg]    │
│              │                    │              │
│  Receive:    │                    │ Send:        │
│  [reply]     │◄───────────────────│ [id][reply]  │
│              │                    │              │
└──────────────┘                    └──────────────┘

Multiple clients can connect to one ROUTER
ROUTER keeps track of client identities
Round-robin load balancing to workers via internal proxy
```

#### Internal Proxy Pattern (Core Service)

```
┌─────────────┐         ┌───────────┐         ┌─────────────┐
│   Clients   │         │   Proxy   │         │   Workers   │
│  (External) │         │  Thread   │         │  (Internal) │
│             │         │           │         │             │
│   DEALER    │◄───────►│   ROUTER  │         │             │
│             │         │     │     │         │             │
│             │         │     │     │         │             │
│             │         │   DEALER  │◄───────►│   DEALER    │
│             │         │           │         │             │
└─────────────┘         └───────────┘         └─────────────┘
     │                        │                      │
     │  tcp://host:7512      │  inproc://workers   │
     │                        │                      │
     │  Load balances to ────┼─────► Thread pool    │
     │  available workers     │       with N workers │
```

### Protocol Buffer Encoding

```
┌─────────────────────────────────────────────────────┐
│           Protobuf Message Example                  │
│                                                     │
│  .proto Definition:                                 │
│  ──────────────────                                 │
│  message RecordCreateRequest {                      │
│      optional string title = 1;                     │
│      optional string metadata = 2;                  │
│      optional string alias = 3;                     │
│  }                                                  │
│                                                     │
│  ─────────────────────────────────────────────────  │
│                                                     │
│  Serialized Binary (wire format):                  │
│  ──────────────────────────────                     │
│  Field 1 (title):                                   │
│  │ Tag: 0x0A (field 1, type string)                │
│  │ Length: 0x07                                     │
│  │ Value: "Example"                                 │
│  │                                                  │
│  Field 2 (metadata):                                │
│  │ Tag: 0x12 (field 2, type string)                │
│  │ Length: 0x0D                                     │
│  │ Value: '{"key":"val"}'                          │
│  │                                                  │
│  │ 0x0A 0x07 0x45 0x78 0x61 0x6D 0x70 0x6C 0x65... │
│                                                     │
└─────────────────────────────────────────────────────┘
```

---

## Database Schema

### Collections and Relationships

```
┌────────────────────────────────────────────────────────┐
│                  ArangoDB Collections                  │
└────────────────────────────────────────────────────────┘

Document Collections:
┌─────┐  ┌─────┐  ┌─────┐  ┌─────┐  ┌──────┐  ┌──────┐
│  u  │  │  d  │  │  c  │  │  p  │  │ repo │  │ task │
│users│  │data │  │coll │  │proj │  │      │  │      │
└─────┘  └─────┘  └─────┘  └─────┘  └──────┘  └──────┘
   │        │        │        │         │         │
   │        │        │        │         │         │
   └────────┴────────┴────────┴─────────┴─────────┴───┐
                                                       │
Edge Collections:                                      │
┌────────┐ ┌──────┐ ┌──────┐ ┌──────┐ ┌──────┐       │
│ owner  │ │ item │ │ alias│ │ acl  │ │ dep  │       │
│        │ │      │ │      │ │      │ │      │       │
└────────┘ └──────┘ └──────┘ └──────┘ └──────┘       │
    │         │         │         │         │         │
    └─────────┴─────────┴─────────┴─────────┴─────────┘
```

### Graph Relationships

```
                    ┌─────────┐
                    │  User   │
                    │  (u/*)  │
                    └────┬────┘
                         │
           ┌─────────────┼─────────────┐
           │ owner       │ owner       │ owner
           │             │             │
           ▼             ▼             ▼
      ┌─────────┐   ┌─────────┐   ┌─────────┐
      │  Data   │   │  Coll   │   │ Project │
      │  (d/*)  │   │  (c/*)  │   │  (p/*)  │
      └────┬────┘   └────┬────┘   └─────────┘
           │             │
           │             │ item
           │             │
           │             ▼
           │        ┌─────────┐
           │        │  Data   │
           │        │  (d/*)  │
           │        └─────────┘
           │
           │ dep (dependency)
           │
           ▼
      ┌─────────┐
      │  Data   │
      │  (d/*)  │
      └─────────┘

ACL Relationships:
┌─────────┐              ┌─────────┐
│  User   │              │  Data   │
│  (u/*)  │─────acl─────►│  (d/*)  │
└─────────┘              └─────────┘
     │                        ▲
     │                        │
     │                        │ acl
     ▼                        │
┌─────────┐              ┌─────────┐
│ Project │──────acl────►│  Coll   │
│  (p/*)  │              │  (c/*)  │
└─────────┘              └─────────┘
```

### Document Structure Examples

```javascript
// User Document (collection: u)
{
    "_key": "jdoe",
    "_id": "u/jdoe",
    "uid": "u/jdoe",
    "name": "John Doe",
    "nameFirst": "John",
    "nameLast": "Doe",
    "email": "jdoe@example.com",
    "options": {
        "theme": "dark",
        "default_ep": "uuid-1234-5678"
    },
    "uuid": ["globus-uuid-1", "globus-uuid-2"],
    "isAdmin": false,
    "isRepo": false
}

// Data Record (collection: d)
{
    "_key": "d12345",
    "_id": "d/d12345",
    "id": "d/d12345",
    "title": "Research Dataset",
    "alias": "experiment_001",
    "desc": "Experimental results from...",
    "owner": "u/jdoe",
    "creator": "u/jdoe",
    "metadata": "{\"temperature\":20,\"pressure\":101}",
    "source": "/path/to/data.hdf5",
    "size": 1048576,
    "ext": ".hdf5",
    "tags": ["physics", "experiment"],
    "ct": 1234567890,  // creation timestamp
    "ut": 1234567900,  // update timestamp
    "doi": "10.1234/example",
    "locked": false
}

// Collection (collection: c)
{
    "_key": "c12345",
    "_id": "c/c12345",
    "id": "c/c12345",
    "title": "2024 Experiments",
    "alias": "2024_exp",
    "owner": "u/jdoe",
    "topic": "research/physics",
    "ct": 1234567890
}

// Project (collection: p)
{
    "_key": "proj001",
    "_id": "p/proj001",
    "id": "p/proj001",
    "title": "Fusion Research",
    "desc": "Multi-year fusion energy research",
    "owner": "u/jdoe",
    "admin": ["u/jdoe", "u/admin2"],
    "member": ["u/member1", "u/member2"],
    "alloc": [
        {"repo": "repo1", "dataLimit": 1000000000000}
    ]
}

// Task (collection: task)
{
    "_key": "task123",
    "_id": "task/task123",
    "id": "task/task123",
    "type": 0,  // XFR (transfer)
    "status": 1,  // running
    "client": "u/jdoe",
    "source": [{"id": "d/d12345"}],
    "dest": [{"id": "d/d67890"}],
    "xfrId": "globus-transfer-uuid",
    "ct": 1234567890,
    "ut": 1234567900,
    "msg": "Transfer in progress"
}

// Edge: Ownership (collection: owner)
{
    "_from": "u/jdoe",
    "_to": "d/d12345"
}

// Edge: Collection Item (collection: item)
{
    "_from": "c/c12345",
    "_to": "d/d12345"
}

// Edge: ACL Grant (collection: acl)
{
    "_from": "u/collaborator",
    "_to": "d/d12345",
    "grant": ["read"]
}

// Edge: Dependency (collection: dep)
{
    "_from": "d/source123",
    "_to": "d/derived456",
    "type": "der"  // derivation
}
```

---

## Deployment Topologies

### Development (Single Node)

```
┌─────────────────────────────────────────────┐
│           Development Machine               │
│                                             │
│  Docker Compose:                            │
│  ┌──────────────────────────────────────┐  │
│  │  ┌──────────┐  ┌──────────┐         │  │
│  │  │ ArangoDB │  │   Web    │         │  │
│  │  │  :8529   │  │  :8080   │         │  │
│  │  └──────────┘  └──────────┘         │  │
│  │                                       │  │
│  │  ┌──────────┐  ┌──────────┐         │  │
│  │  │   Core   │  │   Repo   │         │  │
│  │  │  :7512   │  │  :7514   │         │  │
│  │  └──────────┘  └──────────┘         │  │
│  └──────────────────────────────────────┘  │
│                                             │
│  Shared volumes:                            │
│  • ./config → /etc/datafed                  │
│  • ./data → /data                           │
│                                             │
└─────────────────────────────────────────────┘
```

### Small Production (2-3 Nodes)

```
┌─────────────────────┐
│   Frontend Node     │
│                     │
│  ┌───────────────┐  │      ┌─────────────────────┐
│  │  Web Service  │  │      │   Backend Node      │
│  │  (HTTPS :443) │  │      │                     │
│  └───────┬───────┘  │      │  ┌───────────────┐  │
│          │          │      │  │  Core Service │  │
│          │          │      │  │    (:7512)    │  │
│          │ZMQ       │      │  └───────┬───────┘  │
└──────────┼──────────┘      │          │          │
           │                 │          │HTTP      │
           │                 │          ▼          │
           └────────────────►│  ┌───────────────┐  │
                             │  │   ArangoDB    │  │
                             │  │    (:8529)    │  │
                             │  └───────────────┘  │
                             │                     │
                             └─────────────────────┘

┌─────────────────────┐
│  Repository Node    │
│                     │
│  ┌───────────────┐  │
│  │  Repo Service │  │
│  │    (:7514)    │  │
│  └───────┬───────┘  │
│          │          │
│          ▼          │
│  ┌───────────────┐  │
│  │    Globus     │  │
│  │   GridFTP     │  │
│  │   (:2811)     │  │
│  └───────┬───────┘  │
│          │          │
│          ▼          │
│  ┌───────────────┐  │
│  │   Storage     │  │
│  │  /data/repo1  │  │
│  └───────────────┘  │
└─────────────────────┘
```

### Large Production (HA/Distributed)

```
                      ┌─────────────────┐
                      │ Load Balancer   │
                      │  (HAProxy/      │
                      │   nginx)        │
                      └────────┬────────┘
                               │
                ┌──────────────┼──────────────┐
                │              │              │
                ▼              ▼              ▼
        ┌─────────────┐┌─────────────┐┌─────────────┐
        │  Web Node 1 ││  Web Node 2 ││  Web Node 3 │
        │   (Active)  ││   (Active)  ││   (Active)  │
        └──────┬──────┘└──────┬──────┘└──────┬──────┘
               │              │              │
               └──────────────┼──────────────┘
                              │ ZMQ
                              ▼
                    ┌──────────────────┐
                    │   Core Service   │
                    │   (Clustered)    │
                    │                  │
                    │  ┌────────────┐  │
                    │  │ N Workers  │  │
                    │  └────────────┘  │
                    └────┬──────────┬──┘
                         │          │
         HTTP/REST       │          │ ZMQ
                         │          │
                         ▼          ▼
              ┌─────────────────┐  ┌─────────────────┐
              │  ArangoDB       │  │  Repo Services  │
              │  Cluster        │  │                 │
              │                 │  │  ┌───────────┐  │
              │ ┌─────────────┐ │  │  │  Repo 1   │  │
              │ │  Coordinator│ │  │  │(Facility A│  │
              │ └─────────────┘ │  │  └───────────┘  │
              │ ┌─────────────┐ │  │  ┌───────────┐  │
              │ │  DB Server 1│ │  │  │  Repo 2   │  │
              │ ├─────────────┤ │  │  │(Facility B│  │
              │ │  DB Server 2│ │  │  └───────────┘  │
              │ ├─────────────┤ │  │  ┌───────────┐  │
              │ │  DB Server 3│ │  │  │  Repo 3   │  │
              │ └─────────────┘ │  │  │(Facility C│  │
              │                 │  │  └───────────┘  │
              │ Sharded/        │  └─────────────────┘
              │ Replicated      │            │
              └─────────────────┘            │
                                             │
                                             ▼
                              ┌──────────────────────────┐
                              │   Distributed Storage    │
                              │                          │
                              │  Facility A    Facility B│
                              │  Storage       Storage   │
                              │                          │
                              │  Facility C              │
                              │  Storage                 │
                              └──────────────────────────┘
```

### Network Diagram with Ports

```
Internet
   │
   │ :443 (HTTPS)
   ▼
┌──────────────┐
│ Firewall/LB  │
└──────┬───────┘
       │
       │ :443, :80
       ▼
┌──────────────┐
│ Web Service  │
└──────┬───────┘
       │
       │ :7512 (ZMQ)
       ▼
┌──────────────┐
│ Core Service │
└──┬────────┬──┘
   │        │
   │:8529   │:7514 (ZMQ)
   │(HTTP)  │
   │        ▼
   │    ┌──────────────┐
   │    │Repo Service  │
   │    └──────┬───────┘
   │           │
   │           │:2811 (GridFTP control)
   │           │:50000-51000 (GridFTP data)
   │           ▼
   │    ┌──────────────┐
   │    │GridFTP Server│
   │    └──────┬───────┘
   │           │
   │           ▼
   │    ┌──────────────┐
   │    │   Storage    │
   │    └──────────────┘
   │
   ▼
┌──────────────┐
│  ArangoDB    │
└──────────────┘

External Services:
┌──────────────┐
│ Globus Auth  │ :443 (HTTPS)
│   API        │
└──────────────┘

┌──────────────┐
│ Globus Xfr   │ :443 (HTTPS)
│   API        │
└──────────────┘
```

---

## Summary

This architecture reference provides visual representations of:

1. **System Overview**: High-level component interaction
2. **Component Architecture**: Internal structure of each service
3. **Data Flow Diagrams**: Request/response flows for key operations
4. **Communication Patterns**: ZeroMQ and protobuf message structure
5. **Database Schema**: Collections, relationships, and document structure
6. **Deployment Topologies**: Various deployment configurations

For implementation details, refer to:
- [DEVELOPER_GUIDE.md](DEVELOPER_GUIDE.md) - Comprehensive development guide
- [QUICK_START.md](QUICK_START.md) - Quick reference guide
- Source code in respective component directories

---

**Legend for Diagrams**:
- `│ ─ ┌ ┐ └ ┘ ├ ┤ ┬ ┴ ┼` - Box drawing characters
- `▼ ▲ ► ◄` - Direction indicators
- `→ ← ↔` - Flow arrows
- `...` - Continuation/omitted details

