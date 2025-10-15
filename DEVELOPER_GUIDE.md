# DataFed Developer Guide

## Table of Contents
1. [Overview](#overview)
2. [System Architecture](#system-architecture)
3. [Technology Stack](#technology-stack)
4. [Project Structure](#project-structure)
5. [Core Components](#core-components)
6. [Communication Protocols](#communication-protocols)
7. [Build System](#build-system)
8. [Development Workflow](#development-workflow)
9. [Testing](#testing)
10. [Deployment](#deployment)
11. [API Reference](#api-reference)

---

## Overview

DataFed is a **federated scientific data management system** designed to support cross-facility research activities including experimentation, simulation, and analytics. It provides the software infrastructure needed to build a loosely-coupled data network between geographically distributed and heterogeneous facilities.

### Key Features
- **Federated Architecture**: Distributed data storage across multiple repositories
- **Unified Access**: Simple, uniform access regardless of physical storage location
- **Metadata Management**: Centralized metadata with distributed raw data
- **Globus Integration**: Data transfer via Globus for secure, reliable transfers
- **Multi-Interface**: Web portal, CLI, and Python API
- **Access Control**: Fine-grained permissions and ACLs

### Version Information
DataFed follows **semantic versioning** with a calendar-based release version:
- **Release Format**: `YEAR.MONTH.DAY.HOUR.MINUTE`
- **API Version**: `MAJOR.MINOR.PATCH`
- Backward compatibility maintained within MINOR versions
- MAJOR version changes break compatibility

---

## System Architecture

### High-Level Architecture

DataFed consists of 6 main services:

```
┌─────────────────────────────────────────────────────────────┐
│                         Users                                │
│  ┌──────────┐    ┌──────────┐    ┌────────────────────┐    │
│  │ Web UI   │    │   CLI    │    │   Python API       │    │
│  └────┬─────┘    └─────┬────┘    └──────────┬─────────┘    │
└───────┼────────────────┼────────────────────┼──────────────┘
        │                │                    │
        ▼                ▼                    ▼
┌─────────────────────────────────────────────────────────────┐
│                   Web Service (Node.js)                      │
│  • Serves web portal (static files + server-rendered pages)  │
│  • Proxies API requests to Core Service                      │
│  • Handles OAuth with Globus Auth                            │
│  • Session management                                         │
└────────────────────────────┬────────────────────────────────┘
                             │ ZeroMQ
                             ▼
┌─────────────────────────────────────────────────────────────┐
│                  Core Service (C++)                          │
│  • Central orchestration and business logic                  │
│  • Request routing and validation                            │
│  • Authentication/Authorization                              │
│  • Globus API integration                                    │
│  • Task management (transfers, allocations, etc.)            │
└─────┬────────────────────────┬──────────────────────────────┘
      │                        │
      │ ArangoDB HTTP API      │ ZeroMQ
      ▼                        ▼
┌──────────────┐      ┌─────────────────────────────────┐
│   Database   │      │   Repository Service(s) (C++)   │
│  (ArangoDB)  │      │  • Data transfer management     │
│  • Foxx App  │      │  • GridFTP/Globus integration   │
│  • Metadata  │      │  • Storage allocation           │
│  • Records   │      │  • Co-located with data store   │
│  • Relations │      └─────────────────────────────────┘
└──────────────┘                     │
                                     │ GridFTP
                    ┌────────────────┴────────────────┐
                    │  Globus GridFTP DSI Module      │
                    │  • Custom Authorization (authz) │
                    │  • Interfaces with Core Service │
                    └─────────────────────────────────┘
                                     │
                                     ▼
                          ┌─────────────────┐
                          │  Data Storage   │
                          └─────────────────┘
```

### Communication Flow

1. **User Request Flow**:
   ```
   User → Web/CLI/API → Web Service → Core Service → Database/Repository
   ```

2. **Data Transfer Flow**:
   ```
   User → Core Service → Repository Service → Globus GridFTP → Storage
   ```

3. **Authentication Flow**:
   ```
   User → Globus Auth → Web Service → Core Service → Database
   ```

---

## Technology Stack

### Core Technologies

#### Backend Services
- **Language**: C++17 (Core & Repository servers)
- **Messaging**: ZeroMQ (DEALER-ROUTER pattern)
- **Serialization**: Protocol Buffers (protobuf)
- **HTTP Client**: libcurl
- **Cryptography**: OpenSSL, libsodium
- **Build System**: CMake 3.17+

#### Web Service
- **Runtime**: Node.js
- **Framework**: Express.js
- **Template Engine**: ECT (EJS-based)
- **Session Management**: express-session
- **Security**: Helmet.js
- **OAuth Client**: client-oauth2

#### Database
- **DBMS**: ArangoDB (graph database)
- **Foxx Framework**: JavaScript microservices in ArangoDB
- **Query Language**: AQL (ArangoDB Query Language)

#### Client Libraries
- **Python**: 3.8+
  - Protocol Buffers
  - ZeroMQ (pyzmq)
  - Requests library
- **CLI**: Python-based command-line interface

#### Data Transfer
- **Globus Transfer API**: For coordinating transfers
- **GridFTP**: Protocol for high-performance data transfer
- **Custom DSI**: DataFed GridFTP DSI module

### Key Dependencies

```cmake
# See cmake/dependency_versions.sh for exact versions
- Protobuf: 3.x (library and compiler)
- ZeroMQ: 4.x
- libsodium: (for ZeroMQ encryption)
- nlohmann JSON: 3.x
- JSON Schema Validator: 2.x
- OpenSSL: 1.1.x or 3.x
- libcurl: 7.x
- Boost: 1.7x (date_time, system, filesystem, program_options)
- zlib: 1.2.x
```

---

## Project Structure

### Directory Layout

```
DataFed/
├── common/                 # Shared code for C++ services
│   ├── include/           # Public headers
│   ├── source/            # Implementation
│   ├── proto/             # Protocol buffer definitions
│   └── tests/             # Unit tests
│
├── core/                   # Core service
│   ├── server/            # Core server implementation
│   │   ├── main.cpp       # Entry point
│   │   ├── CoreServer.cpp # Main server class
│   │   ├── ClientWorker.cpp # Client request handlers
│   │   ├── TaskWorker.cpp   # Background task processing
│   │   ├── DatabaseAPI.cpp  # ArangoDB interface
│   │   └── GlobusAPI.cpp    # Globus API interface
│   └── database/          # Database setup and Foxx app
│       └── foxx/          # ArangoDB Foxx microservices
│           ├── api/       # REST API routers
│           ├── tests/     # JavaScript tests
│           └── index.js   # Foxx entry point
│
├── repository/             # Repository service
│   ├── server/            # Repo server implementation
│   └── gridftp/           # GridFTP DSI module
│
├── web/                    # Web service
│   ├── datafed-ws.js      # Main web server (Node.js)
│   ├── static/            # Frontend assets
│   │   ├── main.js        # Main frontend app
│   │   ├── api.js         # Frontend API client
│   │   ├── dialogs.js     # UI dialogs
│   │   ├── components/    # Reusable components
│   │   └── jquery/        # jQuery and plugins
│   ├── views/             # ECT templates
│   └── services/          # Backend service modules
│       └── auth/          # Authentication handlers
│
├── python/                 # Python client
│   └── datafed_pkg/
│       └── datafed/
│           ├── CommandLib.py   # High-level API
│           ├── MessageLib.py   # Low-level messaging
│           ├── Connection.py   # ZeroMQ connection
│           └── CLI.py          # Command-line interface
│
├── scripts/                # Installation and utility scripts
│   ├── install_*.sh       # Installation scripts
│   ├── generate_*.sh      # Config generation
│   └── globus/            # Globus-specific utilities
│
├── cmake/                  # CMake modules
│   ├── *.cmake            # Find/build dependency scripts
│   └── Version.cmake      # Version management
│
├── compose/                # Docker Compose setups
│   ├── all/               # Full stack deployment
│   ├── repo/              # Repository-only deployment
│   └── metadata/          # Metadata-only deployment
│
├── docker/                 # Dockerfiles
│   ├── Dockerfile.dependencies  # Build dependencies
│   ├── Dockerfile.runtime      # Runtime image
│   └── Dockerfile.foxx         # Foxx deployment
│
├── tests/                  # End-to-end tests
│   └── end-to-end/
│       ├── *.py           # Python API tests
│       └── web-UI/        # Web UI tests (Playwright)
│
├── doc_source/             # Sphinx documentation source
│   └── source/            # RST files
│
└── docs/                   # Built documentation (HTML)
```

### Key Configuration Files

```
config/
├── datafed.sh             # Main configuration (generated)
└── gsi-authz.conf         # GridFTP authorization config

CMakeLists.txt             # Root CMake configuration
pyproject.toml             # Python project configuration
eslint.config.js           # JavaScript linting
```

---

## Core Components

### 1. Core Service (C++)

**Location**: `core/server/`

The Core Service is the central orchestration component written in C++.

#### Main Classes

**CoreServer** (`CoreServer.cpp/hpp`)
- Main server class
- Initializes ZeroMQ sockets (ROUTER for clients, DEALER for repos)
- Manages worker threads
- Handles configuration

**ClientWorker** (`ClientWorker.cpp/hpp`)
- Processes client requests
- Implements business logic for all API operations
- Authenticates and authorizes requests
- Interfaces with DatabaseAPI and GlobusAPI

**TaskWorker** (`TaskWorker.cpp/hpp`)
- Background task processing
- Manages data transfers
- Handles task state transitions
- Periodic maintenance tasks

**DatabaseAPI** (`DatabaseAPI.cpp/hpp`)
- Interface to ArangoDB
- HTTP/REST client for Foxx services
- Handles database queries and updates
- JSON parsing and construction

**GlobusAPI** (`GlobusAPI.cpp/hpp`)
- Interface to Globus services
- OAuth token management
- Transfer API integration
- Endpoint management

**Key Features**:
- Multi-threaded request processing
- Protocol buffer message serialization
- ZeroMQ for inter-service communication
- Session and credential management
- Fine-grained access control

#### Message Flow

```cpp
// Simplified message processing flow
1. CoreServer receives ZeroMQ message
2. Extracts client ID and message type
3. Dispatches to available ClientWorker
4. ClientWorker:
   - Deserializes protobuf message
   - Authenticates/authorizes request
   - Processes business logic
   - Calls DatabaseAPI or GlobusAPI as needed
   - Serializes response
   - Sends reply via ZeroMQ
```

### 2. Database Layer (ArangoDB + Foxx)

**Location**: `core/database/foxx/`

DataFed uses **ArangoDB** as its database with **Foxx** microservices providing the data access layer.

#### Why ArangoDB?
- **Multi-model**: Document, graph, and key-value in one database
- **Graph capabilities**: Native support for relationships
- **Foxx framework**: JavaScript microservices running in the database
- **AQL**: Powerful query language
- **Performance**: Efficient indexing and querying

#### Foxx Application Structure

```javascript
foxx/
├── index.js              // Foxx app entry point, registers routes
├── api/                  // API routers
│   ├── data_router.js    // Data record operations
│   ├── coll_router.js    // Collection operations
│   ├── proj_router.js    // Project operations
│   ├── user_router.js    // User operations
│   ├── repo_router.js    // Repository operations
│   ├── authz_router.js   // Authorization
│   └── models/           // Data models
│       ├── user.js
│       ├── globus_token.js
│       └── globus_collection.js
└── tests/                // JavaScript unit tests
```

#### Key Collections

```javascript
// Core collections
- u (users): User accounts and profiles
- p (projects): Research projects
- d (data): Data records (metadata only)
- c (collections): Hierarchical data organization
- repo: Data repositories
- alloc: Storage allocations
- task: Transfer and processing tasks
- acl: Access control lists
- alias: ID aliases

// Relationships (edges)
- owner: Ownership relationships
- member: Project/group membership
- item: Collection item membership
- dep: Data dependencies
```

#### Example Foxx Route

```javascript
// From api/data_router.js
router.post('/create', function (req, res) {
    try {
        // Parse request
        const client = req.queryParams.client;
        const data = req.body;
        
        // Validate permissions
        authz.checkPermissions(client, 'CREATE_DATA');
        
        // Create record
        const result = db._query(aql`
            INSERT ${data} INTO d
            RETURN NEW
        `).toArray();
        
        res.json(result[0]);
    } catch (e) {
        res.throw(400, e.message);
    }
});
```

### 3. Web Service (Node.js/Express)

**Location**: `web/datafed-ws.js`

The Web Service provides:
1. Static file serving (web portal)
2. Server-side rendering (ECT templates)
3. API proxy to Core Service
4. OAuth authentication via Globus
5. Session management

#### Key Responsibilities

**Authentication Flow**:
```javascript
// 1. Login redirect to Globus
app.get('/ui/login', (req, res) => {
    var uri = g_globus_auth.code.getUri();
    res.redirect(uri);
});

// 2. OAuth callback
app.get('/ui/authn', (req, res) => {
    // Exchange code for tokens
    // Verify user in DataFed
    // Create session
    // Redirect to main app
});

// 3. Session validation
function sendMessage(msg_name, msg_data, req, res, callback) {
    var client = req.session.uid;
    if (!client) {
        throw "Not Authenticated";
    }
    // Forward to Core Service via ZeroMQ
}
```

**API Proxying**:
```javascript
// Example API endpoint
app.get('/api/dat/view', (req, res) => {
    sendMessage(
        'RecordViewRequest',
        { id: req.query.id },
        req,
        res,
        function(reply) {
            res.json(reply);
        }
    );
});
```

**ZeroMQ Communication**:
```javascript
// Message structure to Core Service:
// [BEGIN_DATAFED][route_count][delim][correlation_id][key][client_id][frame][protobuf_msg]

// Frame contains:
// - Message length (4 bytes)
// - Protocol ID (1 byte)
// - Message ID (1 byte)
// - Context ID (2 bytes) - for matching replies
```

#### Frontend Architecture

**Location**: `web/static/`

The frontend is a jQuery-based SPA (Single Page Application):

```javascript
// Main modules
main.js              // App initialization
main_browse_tab.js   // Main data browser
api.js               // Backend API client
dialogs.js           // UI dialogs
util.js              // Utilities
settings.js          // User settings
model.js             // Data models

// Components
components/
├── endpoint-browse/     // Globus endpoint browser
├── provenance/          // Provenance graph visualization
└── transfer/            // Data transfer dialogs
```

**API Client Pattern**:
```javascript
// web/static/api.js
export function recordView(id, callback) {
    $.ajax({
        url: `/api/dat/view?id=${encodeURIComponent(id)}`,
        method: 'GET',
        success: function(data) {
            callback(true, data);
        },
        error: function(xhr) {
            callback(false, xhr.responseText);
        }
    });
}
```

### 4. Repository Service (C++)

**Location**: `repository/server/`

The Repository Service manages data storage and transfers at individual repositories.

#### Key Classes

**RepoServer** (`RepoServer.cpp/hpp`)
- Connects to Core Service via ZeroMQ
- Manages local storage
- Interfaces with Globus GridFTP

**RequestWorker** (`RequestWorker.cpp/hpp`)
- Processes transfer requests
- Manages Globus transfer tasks
- Updates task status

#### Data Transfer Flow

```
1. User initiates transfer via Core Service
2. Core creates Task record
3. Core sends transfer request to appropriate Repo Service(s)
4. Repo Service:
   - Validates storage allocation
   - Initiates Globus transfer
   - Monitors transfer status
   - Updates task in Core
5. On completion, updates data record size/status
```

### 5. GridFTP Authorization Module

**Location**: `repository/gridftp/`

Custom GridFTP DSI (Data Storage Interface) module that:
- Intercepts GridFTP authorization requests
- Validates permissions via Core Service
- Enforces storage quotas
- Logs access for auditing

```c++
// Simplified authorization flow
int datafed_authorize_path(char *path, char *client_id) {
    // 1. Extract DataFed record ID from path
    // 2. Query Core Service for permissions
    // 3. Check storage allocation
    // 4. Return authorized/denied
}
```

### 6. Python Client

**Location**: `python/datafed_pkg/datafed/`

Provides both programmatic API and CLI access.

#### Architecture Layers

```python
# High-level API (CommandLib.py)
class API:
    def dataCreate(self, title, **kwargs):
        # Validates parameters
        # Constructs protobuf message
        # Calls MessageLib
        # Returns result

# Low-level messaging (MessageLib.py)
class API:
    def sendMessage(self, msg_type, msg_data):
        # Serializes protobuf
        # Sends via ZeroMQ
        # Waits for reply
        # Deserializes response

# Connection management (Connection.py)
class Connection:
    def connect(self):
        # Establishes ZeroMQ DEALER socket
        # Loads credentials
        # Connects to server
```

#### Example Usage

```python
from datafed import CommandLib as df

# Initialize API
api = df.API()

# Authenticate
api.loginByPassword("username", "password")

# Create data record
record = api.dataCreate(
    title="My Dataset",
    description="Example data",
    metadata={"key": "value"}
)

# Upload data
api.dataPut(record.data[0].id, "/path/to/file")

# Search
results = api.dataSearch(query="example", offset=0, count=10)
```

---

## Communication Protocols

### 1. Protocol Buffers

DataFed uses **Protocol Buffers** (protobuf) for message serialization.

**Location**: `common/proto/common/`

#### Message Categories

```protobuf
// SDMS_Anon.proto - Anonymous/unauthenticated messages
message VersionRequest {}
message VersionReply {
    optional uint32 release_year = 1;
    optional uint32 api_major = 6;
    // ...
}

message AuthenticateByPasswordRequest {
    required string uid = 1;
    required string password = 2;
}

// SDMS_Auth.proto - Authenticated messages  
message RecordCreateRequest {
    optional string title = 1;
    optional string alias = 2;
    optional string metadata = 3;
    // ...
}

message RecordCreateReply {
    repeated RecordData data = 1;
}
```

#### Version Compatibility

```protobuf
// Version.proto.in (generated during build)
enum Version {
    DATAFED_RELEASE_YEAR = @DATAFED_RELEASE_YEAR@;
    DATAFED_API_MAJOR = @DATAFED_API_MAJOR@;
    DATAFED_API_MINOR = @DATAFED_API_MINOR@;
    // ...
}
```

**Rules**:
- Adding/removing messages → increment API_MAJOR (breaking)
- Appending fields to messages → increment API_MINOR (compatible)
- Deprecated fields marked but not removed until next major version

### 2. ZeroMQ Messaging

DataFed uses **ZeroMQ** for inter-service communication.

#### Socket Patterns

```
Web Service → Core Service:
  DEALER → ROUTER (request-reply with load balancing)

Core Service → Repository Services:
  DEALER → ROUTER (request-reply with load balancing)

Python Client → Core Service:
  DEALER → ROUTER (direct connection)
```

#### Message Frame Structure

```
[Delimiter: "BEGIN_DATAFED"]
[Route Count: 4 bytes]
[Delimiter: empty frame]
[Correlation ID: UUID]
[Encryption Key ID: string]
[Client ID: string]
[Message Frame: 8 bytes]
  ├─ Message Length: 4 bytes
  ├─ Protocol ID: 1 byte
  ├─ Message ID: 1 byte
  └─ Context ID: 2 bytes (for reply matching)
[Protobuf Payload: variable length]
```

#### Security

- **Encryption**: Optional CurveZMQ (libsodium)
- **Authentication**: Message-level client ID validation
- **Key Management**: RSA key pairs for services

### 3. HTTP/REST APIs

#### Globus API Integration

```cpp
// Core Service → Globus Transfer API
POST /v0.10/transfer
Authorization: Bearer <access_token>
{
    "DATA_TYPE": "transfer",
    "source_endpoint": "uuid",
    "destination_endpoint": "uuid",
    "DATA": [...]
}
```

#### Foxx HTTP Interface

```javascript
// Core Service → Foxx (ArangoDB)
POST /_db/sdms/datafed/api/data/create
Content-Type: application/json
{
    "title": "Record Title",
    "metadata": {...}
}
```

---

## Build System

### CMake Build Process

DataFed uses **CMake** 3.17+ with custom modules for dependency management.

#### Build Options

```bash
# Core build options (see CMakeLists.txt)
-DBUILD_CORE_SERVER=ON       # Build core service
-DBUILD_REPO_SERVER=ON       # Build repository service
-DBUILD_WEB_SERVER=ON        # Build web service
-DBUILD_PYTHON_CLIENT=ON     # Build Python client
-DBUILD_AUTHZ=ON            # Build GridFTP authz module
-DBUILD_FOXX=ON             # Build Foxx app
-DBUILD_DOCS=ON             # Build documentation
-DBUILD_TESTS=ON            # Build tests

# Test options
-DENABLE_UNIT_TESTS=ON
-DENABLE_END_TO_END_API_TESTS=ON
-DENABLE_END_TO_END_WEB_TESTS=ON
-DENABLE_FOXX_TESTS=ON

# Library linking
-DBUILD_SHARED_LIBS=OFF     # Static by default
```

#### Dependency Resolution

Dependencies are managed via custom CMake modules in `cmake/`:

```cmake
# Example: cmake/Protobuf.cmake
find_package(Protobuf ${PROTOBUF_LIBRARY_VERSION} REQUIRED)

# Generate protobuf files
protobuf_generate_cpp(PROTO_SRCS PROTO_HDRS ${ProtoFiles})

# Make available to targets
set(DATAFED_PROTOBUF_LIBRARY_PATH ${Protobuf_LIBRARIES})
```

**Dependency Installation**:
```bash
# Install all dependencies
./scripts/install_dependencies.sh

# Or individual components
./scripts/install_core_dependencies.sh
./scripts/install_web_dependencies.sh
./scripts/install_python_client_dependencies.sh
```

#### Build Workflow

```bash
# 1. Generate configuration
./scripts/generate_datafed.sh

# 2. Configure build
mkdir build && cd build
cmake .. \
    -DBUILD_CORE_SERVER=ON \
    -DBUILD_WEB_SERVER=ON \
    -DBUILD_PYTHON_CLIENT=ON

# 3. Build
make -j$(nproc)

# 4. Run tests
ctest --output-on-failure

# 5. Install
sudo make install
```

### Web Service Build

The web service uses **Node.js** with npm:

```bash
# Location: web/
cd web

# Install dependencies
npm install

# Run tests
npm test

# Run locally
node datafed-ws.js /path/to/config.conf
```

**Key npm scripts** (from `package.json.in`):
```json
{
    "scripts": {
        "test": "jest",
        "lint": "eslint .",
        "format": "prettier --write ."
    }
}
```

### Python Client Build

```bash
# Location: python/datafed_pkg/
cd python/datafed_pkg

# Build protobuf bindings
python3 pyproto_add_msg_idx.py

# Install in development mode
pip install -e .

# Or build wheel
python3 setup.py bdist_wheel
```

---

## Development Workflow

### 1. Setting Up Development Environment

#### Prerequisites

```bash
# System packages (Ubuntu/Debian)
sudo apt-get install -y \
    build-essential cmake git \
    libssl-dev libcurl4-openssl-dev \
    libboost-all-dev \
    nodejs npm \
    python3 python3-pip

# Clone repository
git clone https://github.com/ORNL/DataFed.git
cd DataFed
```

#### Configuration

```bash
# Generate configuration files
./scripts/generate_datafed.sh

# Edit configuration
vi config/datafed.sh

# Set environment variables
source config/datafed.sh
```

### 2. Local Development Setup

#### Running Services Locally

**Core Service**:
```bash
cd build/core/server
./datafed-core --cfg /path/to/core.conf
```

**Web Service**:
```bash
cd web
node datafed-ws.js /path/to/web.conf
```

**Database** (ArangoDB):
```bash
# Start ArangoDB
arangod --server.endpoint tcp://0.0.0.0:8529

# Install Foxx app
foxx install /datafed core/database/foxx
```

#### Using Docker Compose

```bash
# Full stack
cd compose/all
./generate_env.sh
docker-compose up

# Metadata only (no Globus/repos)
cd compose/metadata
./generate_env.sh
docker-compose up
```

### 3. Code Organization Best Practices

#### C++ Code Style

```cpp
// Header guards
#ifndef COMPONENT_CLASSNAME_HPP
#define COMPONENT_CLASSNAME_HPP
#pragma once

// Namespace organization
namespace SDMS {
namespace Core {

// Class structure
class ClassName {
public:
    ClassName();
    virtual ~ClassName();
    
    // Public interface
    void publicMethod();
    
private:
    // Private implementation
    void privateMethod();
    
    // Member variables with m_ prefix
    int m_member_var;
};

} // namespace Core
} // namespace SDMS

#endif
```

#### JavaScript Code Style

```javascript
// ES6 modules
import { something } from './module.js';

// Function documentation
/**
 * @brief Short description
 * @param {string} param - Parameter description
 * @returns {Object} Return value description
 */
function functionName(param) {
    // Implementation
}

// Consistent naming
const CONSTANT_VALUE = 42;
let variableName = "value";
function functionName() {}
class ClassName {}
```

#### Python Code Style

```python
"""Module docstring."""

from typing import Optional, Dict, Any

class APIClass:
    """Class docstring.
    
    Attributes:
        attr_name: Description
    """
    
    def method_name(self, param: str) -> Dict[str, Any]:
        """Method docstring.
        
        Args:
            param: Parameter description
            
        Returns:
            Return value description
            
        Raises:
            Exception: When something goes wrong
        """
        pass
```

### 4. Adding New Features

#### Adding a New API Endpoint

**1. Define Protocol Buffer Message**:
```protobuf
// common/proto/common/SDMS_Auth.proto
message NewFeatureRequest {
    required string param1 = 1;
    optional string param2 = 2;
}

message NewFeatureReply {
    repeated ResultData results = 1;
}
```

**2. Implement in Core Service**:
```cpp
// core/server/ClientWorker.cpp
void ClientWorker::procNewFeatureRequest(
    const std::string &a_uid,
    const Auth::NewFeatureRequest &a_request,
    Auth::NewFeatureReply &a_reply
) {
    // Validate permissions
    checkPermissions(a_uid, PERM_RD_REC);
    
    // Business logic
    // ...
    
    // Call database
    m_db_client.newFeatureQuery(params, a_reply);
}
```

**3. Add Foxx Handler**:
```javascript
// core/database/foxx/api/feature_router.js
router.post('/new_feature', function(req, res) {
    const client = req.queryParams.client;
    const data = req.body;
    
    // Process request
    const result = processNewFeature(client, data);
    
    res.json(result);
});
```

**4. Add Web Service Endpoint**:
```javascript
// web/datafed-ws.js
app.post('/api/feature/new', (req, res) => {
    sendMessage(
        'NewFeatureRequest',
        req.body,
        req,
        res,
        function(reply) {
            res.json(reply);
        }
    );
});
```

**5. Add Python Client Method**:
```python
# python/datafed_pkg/datafed/CommandLib.py
class API:
    def newFeature(self, param1, param2=None):
        """Execute new feature.
        
        Args:
            param1 (str): First parameter
            param2 (str, optional): Second parameter
            
        Returns:
            NewFeatureReply: Results
        """
        msg = auth.NewFeatureRequest(
            param1=param1,
            param2=param2
        )
        return self._mapi.sendMessage('NewFeatureRequest', msg)
```

**6. Add Frontend UI**:
```javascript
// web/static/dialogs.js
export function dlgNewFeature(callback) {
    var html = `
        <div>
            <label>Param 1:</label>
            <input type="text" id="param1"/>
        </div>
    `;
    
    $dialog = $(html).dialog({
        title: "New Feature",
        buttons: {
            "Execute": function() {
                api.newFeature(
                    $('#param1').val(),
                    function(ok, data) {
                        callback(ok, data);
                    }
                );
            }
        }
    });
}
```

### 5. Testing Your Changes

#### Unit Tests

```bash
# C++ unit tests
cd build
ctest -R unit_tests_common

# JavaScript/Foxx tests
cd build
ctest -R unit_tests_foxx

# Web service tests
cd web
npm test

# Python tests
cd python/datafed_pkg
pytest
```

#### Integration Tests

```bash
# End-to-end API tests
cd build
ctest -R end_to_end_api

# End-to-end web tests
cd build
ctest -R end_to_end_web
```

#### Manual Testing

```bash
# Test with Python client
python3 -c "
from datafed import CommandLib as df
api = df.API()
api.loginByPassword('user', 'pass')
result = api.newFeature('test')
print(result)
"

# Test with CLI
datafed --password new_feature --param1 test

# Test via web UI
# Navigate to http://localhost/ui/main
```

---

## Testing

### Test Structure

```
tests/
├── unit/                   # Component-level tests
│   ├── common/            # Common library tests (C++)
│   ├── foxx/              # Foxx tests (JavaScript)
│   └── web/               # Web service tests (JavaScript/Jest)
│
└── end-to-end/            # Integration tests
    ├── *.py               # Python API tests
    └── web-UI/            # Web UI tests (Playwright)
```

### Unit Testing

#### C++ Tests (Boost.Test)

```cpp
// common/tests/unit/test_util.cpp
#define BOOST_TEST_MODULE UtilTests
#include <boost/test/unit_test.hpp>
#include "common/Util.hpp"

BOOST_AUTO_TEST_SUITE(UtilTestSuite)

BOOST_AUTO_TEST_CASE(test_escape_json) {
    std::string input = "test\"quote";
    std::string result = escapeJSON(input);
    BOOST_CHECK_EQUAL(result, "test\\\"quote");
}

BOOST_AUTO_TEST_SUITE_END()
```

#### JavaScript Tests (Jest)

```javascript
// web/test/api.test.js
const api = require('../static/api.js');

describe('API Client', () => {
    test('recordView formats request correctly', () => {
        const spy = jest.spyOn($, 'ajax');
        api.recordView('d/12345', () => {});
        
        expect(spy).toHaveBeenCalledWith(
            expect.objectContaining({
                url: '/api/dat/view?id=d%2F12345'
            })
        );
    });
});
```

#### Foxx Tests

```javascript
// core/database/foxx/tests/user_router.test.js
const { expect } = require('chai');
const request = require('@arangodb/request');

describe('User Router', () => {
    it('should create user', () => {
        const response = request.post('/_db/sdms/datafed/api/user/create', {
            json: {
                uid: 'testuser',
                email: 'test@example.com'
            }
        });
        
        expect(response.status).to.equal(200);
        expect(response.json.uid).to.equal('testuser');
    });
});
```

### Integration Testing

#### End-to-End API Tests

```python
# tests/end-to-end/test_data_lifecycle.py
import pytest
from datafed import CommandLib as df

@pytest.fixture
def api():
    api = df.API()
    api.loginByPassword('testuser', 'testpass')
    return api

def test_data_create_update_delete(api):
    # Create
    record = api.dataCreate(
        title="Test Record",
        metadata='{"key":"value"}'
    )
    assert record.data[0].title == "Test Record"
    
    # Update
    updated = api.dataUpdate(
        record.data[0].id,
        title="Updated Title"
    )
    assert updated.data[0].title == "Updated Title"
    
    # Delete
    api.dataDelete([record.data[0].id])
```

#### Web UI Tests (Playwright)

```javascript
// tests/end-to-end/web-UI/test_login.js
const { test, expect } = require('@playwright/test');

test('user can login', async ({ page }) => {
    await page.goto('http://localhost/ui/welcome');
    
    await page.click('text=Login');
    
    // Globus OAuth flow
    await page.fill('#username', 'testuser');
    await page.fill('#password', 'testpass');
    await page.click('button[type=submit]');
    
    // Should redirect to main page
    await expect(page).toHaveURL(/.*\/ui\/main/);
    await expect(page.locator('#uname')).toBeVisible();
});
```

### Test Data Management

```python
# tests/end-to-end/fixtures.py
@pytest.fixture(scope='session')
def test_project(api):
    """Create test project."""
    proj = api.projectCreate(
        id='test_proj',
        title='Test Project'
    )
    yield proj
    api.projectDelete(proj.id)

@pytest.fixture
def test_data(api, test_project):
    """Create test data record."""
    data = api.dataCreate(
        title='Test Data',
        project=test_project.id
    )
    yield data
    api.dataDelete([data.data[0].id])
```

### Running Tests

```bash
# All tests
cd build
ctest --output-on-failure

# Specific test suite
ctest -R unit_tests_common
ctest -R end_to_end_api

# Verbose output
ctest -V -R test_name

# Run in parallel
ctest -j8

# Python tests directly
cd tests/end-to-end
pytest -v test_data_lifecycle.py

# Web UI tests
cd tests/end-to-end/web-UI
npx playwright test
```

---

## Deployment

### Deployment Architectures

#### 1. Single-Node Development

```
┌─────────────────────────────┐
│      Single Server          │
│  ┌─────────────────────┐   │
│  │   Web Service       │   │
│  ├─────────────────────┤   │
│  │   Core Service      │   │
│  ├─────────────────────┤   │
│  │   ArangoDB          │   │
│  ├─────────────────────┤   │
│  │   Repo Service      │   │
│  ├─────────────────────┤   │
│  │   Globus GridFTP    │   │
│  └─────────────────────┘   │
└─────────────────────────────┘
```

#### 2. Production Multi-Node

```
                    ┌──────────────┐
                    │ Load Balancer│
                    └──────┬───────┘
                           │
         ┌─────────────────┴─────────────────┐
         │                                   │
    ┌────▼────┐                         ┌────▼────┐
    │  Web    │                         │  Web    │
    │ Service │                         │ Service │
    └────┬────┘                         └────┬────┘
         │                                   │
         └──────────────┬────────────────────┘
                        │
                   ┌────▼────┐
                   │  Core   │
                   │ Service │
                   └────┬────┘
                        │
         ┌──────────────┼──────────────┐
         │              │              │
    ┌────▼────┐    ┌────▼────┐    ┌────▼────┐
    │ArangoDB │    │  Repo   │    │  Repo   │
    │ Cluster │    │Service 1│    │Service 2│
    └─────────┘    └────┬────┘    └────┬────┘
                        │              │
                   ┌────▼────┐    ┌────▼────┐
                   │Storage 1│    │Storage 2│
                   └─────────┘    └─────────┘
```

### Docker Deployment

#### Building Images

```bash
# Build dependencies image
docker build -f docker/Dockerfile.dependencies \
    -t datafed-deps:latest .

# Build runtime image
docker build -f docker/Dockerfile.runtime \
    --build-arg DEPS_IMAGE=datafed-deps:latest \
    -t datafed-runtime:latest .

# Build Foxx image
docker build -f docker/Dockerfile.foxx \
    -t datafed-foxx:latest .
```

#### Docker Compose Deployment

```yaml
# compose/all/compose.yml (simplified)
version: '3.8'

services:
  arangodb:
    image: arangodb:3.12
    environment:
      ARANGO_ROOT_PASSWORD: ${DB_PASSWORD}
    volumes:
      - arango-data:/var/lib/arangodb3
    ports:
      - "8529:8529"

  core:
    image: datafed-runtime:latest
    command: datafed-core --cfg /etc/datafed/core.conf
    volumes:
      - ./config:/etc/datafed
    depends_on:
      - arangodb
    ports:
      - "7512:7512"

  web:
    image: node:18
    command: node /app/datafed-ws.js /etc/datafed/web.conf
    volumes:
      - ./web:/app
      - ./config:/etc/datafed
    depends_on:
      - core
    ports:
      - "443:443"

  repo:
    image: datafed-runtime:latest
    command: datafed-repo --cfg /etc/datafed/repo.conf
    volumes:
      - ./config:/etc/datafed
      - repo-data:/data
    depends_on:
      - core

volumes:
  arango-data:
  repo-data:
```

### Manual Installation

#### Core Service Installation

```bash
# 1. Install dependencies
./scripts/install_core_dependencies.sh

# 2. Build
mkdir build && cd build
cmake -DBUILD_CORE_SERVER=ON ..
make -j$(nproc)

# 3. Install
sudo make install

# 4. Configure
./scripts/generate_core_config.sh
sudo vi /etc/datafed/core.conf

# 5. Create systemd service
./scripts/generate_core_service.sh
sudo systemctl enable datafed-core
sudo systemctl start datafed-core
```

#### Web Service Installation

```bash
# 1. Install Node.js dependencies
cd web
npm install --production

# 2. Configure
./scripts/generate_ws_config.sh
sudo vi /etc/datafed/web.conf

# 3. Install SSL certificates
sudo ./scripts/install_lego_and_certificates.sh

# 4. Create systemd service
./scripts/generate_ws_service.sh
sudo systemctl enable datafed-web
sudo systemctl start datafed-web
```

#### Repository Service Installation

```bash
# 1. Install Globus Connect Server
./scripts/install_gcs.sh

# 2. Install repository dependencies
./scripts/install_repo_dependencies.sh

# 3. Build
cmake -DBUILD_REPO_SERVER=ON -DBUILD_AUTHZ=ON ..
make -j$(nproc)
sudo make install

# 4. Configure
./scripts/generate_repo_config.sh
./scripts/generate_authz_config.sh

# 5. Setup Globus
./scripts/globus/setup_globus.sh
./scripts/globus/setup_collection_directory.sh

# 6. Start service
sudo systemctl enable datafed-repo
sudo systemctl start datafed-repo
```

### Configuration Files

#### Core Service Config

```ini
# /etc/datafed/core.conf
[server]
port = 7512
cred_dir = /etc/datafed/keys

[database]
url = http://localhost:8529
user = root
password = ${DB_PASSWORD}

[globus]
oauth_url = https://auth.globus.org
xfr_url = https://transfer.api.globus.org
client_id = ${GLOBUS_CLIENT_ID}
client_secret = ${GLOBUS_CLIENT_SECRET}

[tasks]
purge_age = 86400
purge_period = 3600
```

#### Web Service Config

```ini
# /etc/datafed/web.conf
[server]
host = datafed.example.org
port = 443
tls = 1
key_file = /etc/datafed/ssl/key.pem
cert_file = /etc/datafed/ssl/cert.pem
extern_url = https://datafed.example.org
session_secret = ${SESSION_SECRET}

[oauth]
client_id = ${GLOBUS_CLIENT_ID}
client_secret = ${GLOBUS_CLIENT_SECRET}

[core]
server_address = tcp://localhost:7512
```

#### Repository Service Config

```ini
# /etc/datafed/repo.conf
[server]
port = 7514
repo_id = repo1
cred_dir = /etc/datafed/keys
storage_path = /data/datafed

[core]
server_address = tcp://core.example.org:7512

[globus]
endpoint_id = ${GLOBUS_ENDPOINT_ID}
```

### Security Considerations

#### SSL/TLS Configuration

```bash
# Use Let's Encrypt with lego
./scripts/install_lego_and_certificates.sh

# Or manual certificate installation
sudo cp server.key /etc/datafed/ssl/
sudo cp server.crt /etc/datafed/ssl/
sudo chmod 600 /etc/datafed/ssl/server.key
```

#### Firewall Rules

```bash
# Web service
sudo ufw allow 443/tcp
sudo ufw allow 80/tcp  # For Let's Encrypt

# Core service
sudo ufw allow 7512/tcp

# Repository service  
sudo ufw allow 7514/tcp

# GridFTP
sudo ufw allow 2811/tcp
sudo ufw allow 50000:51000/tcp
```

#### Secrets Management

```bash
# Generate session secret
SESSION_SECRET=$(openssl rand -base64 32)

# Store in environment or vault
export DATAFED_SESSION_SECRET="${SESSION_SECRET}"

# Or use systemd EnvironmentFile
echo "SESSION_SECRET=${SESSION_SECRET}" | \
    sudo tee /etc/datafed/secrets.env
sudo chmod 600 /etc/datafed/secrets.env
```

### Monitoring and Logging

#### Systemd Journal

```bash
# View core service logs
sudo journalctl -u datafed-core -f

# View web service logs
sudo journalctl -u datafed-web -f

# Filter by time
sudo journalctl -u datafed-core --since "1 hour ago"
```

#### Log Files

```bash
# Core service (if configured)
tail -f /var/log/datafed/core.log

# Web service
tail -f /var/log/datafed/web.log

# GridFTP
tail -f /var/log/gridftp.log
```

#### Health Checks

```bash
# Check service status
systemctl status datafed-core
systemctl status datafed-web

# Check database
curl http://localhost:8529/_api/version

# Check Globus endpoint
globus endpoint show ${ENDPOINT_ID}
```

### Backup and Recovery

#### Database Backup

```bash
# ArangoDB backup
arangodump \
    --server.endpoint tcp://localhost:8529 \
    --server.username root \
    --server.database sdms \
    --output-directory /backup/arango/$(date +%Y%m%d)

# Automated backup script
./scripts/generate_datafed_backup_script.sh
sudo crontab -e
# Add: 0 2 * * * /usr/local/bin/datafed-backup.sh
```

#### Configuration Backup

```bash
# Backup configuration
tar czf datafed-config-$(date +%Y%m%d).tar.gz \
    /etc/datafed

# Backup keys
sudo tar czf datafed-keys-$(date +%Y%m%d).tar.gz \
    --exclude='*.pub' \
    /etc/datafed/keys
```

---

## API Reference

### Python Client API

#### High-Level API (CommandLib)

**Authentication**:
```python
# Password authentication
api.loginByPassword(uid: str, password: str) -> bool

# Token authentication
api.loginByToken(token: str) -> bool

# Check authentication status
api.getAuthUser() -> Optional[str]

# Logout
api.logout() -> None
```

**Data Records**:
```python
# Create data record
api.dataCreate(
    title: str,
    alias: str = None,
    description: str = None,
    tags: List[str] = None,
    metadata: Union[str, dict] = None,
    parent: str = None,
    deps: List[str] = None,
    repo: str = None,
    **kwargs
) -> RecordCreateReply

# View data record
api.dataView(
    data_id: str,
    context: str = None
) -> RecordDataReply

# Update data record
api.dataUpdate(
    data_id: str,
    title: str = None,
    alias: str = None,
    description: str = None,
    metadata: Union[str, dict] = None,
    metadata_set: bool = False,
    deps_add: List[str] = None,
    deps_rem: List[str] = None,
    **kwargs
) -> RecordUpdateReply

# Delete data record(s)
api.dataDelete(
    data_ids: List[str]
) -> AckReply

# Search data
api.dataSearch(
    query: str = None,
    query_comp: str = None,
    offset: int = 0,
    count: int = 20,
    **kwargs
) -> ListingReply
```

**Data Transfer**:
```python
# Upload data
api.dataPut(
    data_id: str,
    source_path: str,
    source_ep: str = None,
    wait: bool = True,
    timeout: int = None,
    **kwargs
) -> TaskDataReply

# Download data
api.dataGet(
    data_id: str,
    dest_path: str,
    dest_ep: str = None,
    wait: bool = True,
    timeout: int = None,
    orig_fname: bool = False,
    **kwargs
) -> TaskDataReply

# Check transfer status
api.taskView(
    task_id: str
) -> TaskDataReply
```

**Collections**:
```python
# Create collection
api.collectionCreate(
    title: str,
    alias: str = None,
    description: str = None,
    parent: str = None,
    **kwargs
) -> CollDataReply

# Add items to collection
api.collectionItemsUpdate(
    coll_id: str,
    add_ids: List[str] = None,
    rem_ids: List[str] = None
) -> AckReply

# List collection contents
api.collectionView(
    coll_id: str,
    offset: int = 0,
    count: int = 100
) -> CollDataReply
```

**Projects**:
```python
# Create project
api.projectCreate(
    id: str,
    title: str,
    description: str = None,
    **kwargs
) -> ProjectDataReply

# View project
api.projectView(
    project_id: str
) -> ProjectDataReply

# List projects
api.projectList(
    as_owner: bool = True,
    as_admin: bool = False,
    as_member: bool = False
) -> ListingReply
```

**Access Control**:
```python
# View ACLs
api.aclView(
    item_id: str
) -> ACLDataReply

# Update ACLs
api.aclUpdate(
    item_id: str,
    rules: List[dict]
) -> ACLDataReply

# Grant access
api.aclBySubject(
    subject_id: str,
    inc_users: bool = True,
    inc_projects: bool = True
) -> ListingReply
```

### REST API (Web Service)

#### Data Endpoints

```http
POST /api/dat/create
Content-Type: application/json

{
    "title": "Record Title",
    "metadata": "{\"key\":\"value\"}"
}

Response: 200 OK
{
    "data": [{
        "id": "d/12345",
        "title": "Record Title",
        "owner": "u/username"
    }]
}
```

```http
GET /api/dat/view?id=d/12345

Response: 200 OK
{
    "data": [{
        "id": "d/12345",
        "title": "Record Title",
        "metadata": "{\"key\":\"value\"}"
    }]
}
```

```http
POST /api/dat/update
Content-Type: application/json

{
    "id": "d/12345",
    "title": "Updated Title"
}
```

```http
GET /api/dat/delete?ids=["d/12345","d/67890"]
```

#### Collection Endpoints

```http
POST /api/col/create
{
    "title": "Collection Name",
    "parent": "c/root"
}
```

```http
GET /api/col/read?id=c/12345&offset=0&count=100
```

```http
GET /api/col/link?coll=c/12345&items=["d/111","d/222"]
```

#### Project Endpoints

```http
POST /api/prj/create
{
    "id": "proj_id",
    "title": "Project Title",
    "desc": "Description"
}
```

```http
GET /api/prj/list?owner=true&offset=0&count=20
```

#### Transfer Endpoints

```http
GET /api/dat/put?id=d/12345&path=/globus/path&encrypt=0
```

```http
GET /api/dat/get?id=d/12345&path=/globus/path&orig_fname=true
```

### CLI Commands

#### Data Commands

```bash
# Create data
datafed data create --title "Title" --metadata '{"key":"value"}'

# View data
datafed data view d/12345

# Update data
datafed data update d/12345 --title "New Title"

# Delete data
datafed data delete d/12345 d/67890

# Search data
datafed data search --query "keywords" --count 20
```

#### Transfer Commands

```bash
# Upload
datafed data put d/12345 /local/file --wait

# Download
datafed data get d/12345 /local/destination --wait

# Bulk transfers
datafed data put d/12345 /local/file1 d/67890 /local/file2

# Check task status
datafed task view task/12345
```

#### Collection Commands

```bash
# Create collection
datafed coll create --title "Collection" --parent c/root

# Add items
datafed coll link c/12345 d/111 d/222

# Remove items
datafed coll unlink c/12345 d/111

# List contents
datafed coll read c/12345
```

#### Project Commands

```bash
# Create project
datafed proj create proj_id --title "Project"

# List projects
datafed proj list --owner

# View project
datafed proj view p/proj_id
```

---

## Appendix

### A. Protocol Buffer Message Index

**Core message types** (from `common/proto/common/`):

- **SDMS_Anon.proto** (Protocol ID: 1)
  - VersionRequest/Reply
  - AuthenticateByPasswordRequest
  - AuthenticateByTokenRequest
  - AuthStatusReply
  
- **SDMS_Auth.proto** (Protocol ID: 2)
  - RecordCreateRequest/Reply
  - RecordViewRequest/Reply
  - RecordUpdateRequest/Reply
  - CollCreateRequest/Reply
  - ProjectCreateRequest/Reply
  - ACLViewRequest/Reply
  - DataPutRequest/TaskDataReply
  - DataGetRequest/TaskDataReply
  - And 100+ more...

### B. Database Schema

**Key collections**:
```javascript
// Users
u: {
    _key: "username",
    uid: "u/username",
    email: "user@example.com",
    name: "Full Name",
    options: {...}
}

// Data records
d: {
    _key: "unique_id",
    id: "d/unique_id",
    title: "Record Title",
    alias: "optional_alias",
    owner: "u/username",
    creator: "u/username",
    metadata: {...},
    size: 12345,
    source: "path/to/file",
    ct: timestamp,
    ut: timestamp
}

// Collections
c: {
    _key: "coll_id",
    id: "c/coll_id",
    title: "Collection Title",
    owner: "u/username",
    topic: "optional/topic"
}

// Projects
p: {
    _key: "proj_id",
    id: "p/proj_id",
    title: "Project Title",
    owner: "u/username",
    admin: ["u/admin1", "u/admin2"],
    member: ["u/member1", "u/member2"]
}
```

**Key edges**:
```javascript
// Ownership: u → d/c/p
owner: { _from: "u/username", _to: "d/12345" }

// Collection items: c → d/c
item: { _from: "c/12345", _to: "d/67890" }

// Dependencies: d → d
dep: { _from: "d/source", _to: "d/derived" }

// ACL grants: u/p → d/c
acl: { 
    _from: "u/username",
    _to: "d/12345",
    grant: ["read", "write"]
}
```

### C. Environment Variables

```bash
# Build configuration
DATAFED_INSTALL_PATH=/opt/datafed
DATAFED_DEPENDENCIES_INSTALL_PATH=/opt/datafed-deps
DATAFED_DOMAIN=datafed.example.org

# Service configuration
DATAFED_CORE_PORT=7512
DATAFED_WEB_PORT=443
DATAFED_DB_URL=http://localhost:8529

# Globus configuration
GLOBUS_CLIENT_ID=your-client-id
GLOBUS_CLIENT_SECRET=your-client-secret
GLOBUS_ENDPOINT_ID=your-endpoint-id

# Database
DB_ROOT_PASSWORD=secure-password
DB_NAME=sdms
```

### D. Useful Links

- **Documentation**: https://ornl.github.io/DataFed/
- **Repository**: https://github.com/ORNL/DataFed
- **Issues**: https://github.com/ORNL/DataFed/issues
- **Globus Docs**: https://docs.globus.org/
- **ArangoDB Docs**: https://www.arangodb.com/docs/
- **ZeroMQ Guide**: https://zguide.zeromq.org/

### E. Common Issues and Solutions

**Build Issues**:
```bash
# Protobuf version mismatch
rm -rf build/
./scripts/install_dependencies.sh
cmake ..

# ZeroMQ linking errors
export LD_LIBRARY_PATH=/opt/datafed-deps/lib:$LD_LIBRARY_PATH
ldconfig
```

**Runtime Issues**:
```bash
# Core service can't connect to database
curl http://localhost:8529/_api/version
# Check database is running

# Web service authentication fails
# Verify Globus OAuth credentials
# Check session secret is set

# Transfer fails
globus endpoint show $ENDPOINT_ID
# Verify endpoint is activated
```

**Development Tips**:
```bash
# Enable debug logging
export DATAFED_LOG_LEVEL=DEBUG

# Run services in foreground
./datafed-core --cfg core.conf --log-level debug

# Clear test database
./scripts/clear_db.sh

# Rebuild protobuf only
cd build
make clean
cmake .. -DBUILD_COMMON=ON
make
```

---

## Conclusion

This guide provides a comprehensive overview of the DataFed system architecture, codebase structure, and development practices. For specific implementation details, refer to the source code and inline documentation. For deployment and operational questions, consult the official documentation at https://ornl.github.io/DataFed/.

**Next Steps**:
1. Set up your development environment following the "Development Workflow" section
2. Explore the codebase starting with the main entry points
3. Run the test suite to verify your setup
4. Try implementing a simple feature to familiarize yourself with the workflow

**Contributing**:
- Follow the code style guidelines
- Write tests for new features
- Update documentation
- Submit pull requests via GitHub

For questions or support, please open an issue on GitHub or contact the DataFed development team.

