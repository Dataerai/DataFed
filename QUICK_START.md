# DataFed Quick Start Guide

## What is DataFed?

DataFed is a **federated scientific data management system** that enables cross-facility research by providing unified access to distributed data storage, integrated with Globus for data transfers.

## 5-Minute Overview

### System Components

| Component | Technology | Purpose |
|-----------|-----------|---------|
| **Core Service** | C++ | Central orchestration, business logic, task management |
| **Web Service** | Node.js/Express | Web portal + API proxy |
| **Database** | ArangoDB + Foxx | Metadata storage + microservices |
| **Repository Service** | C++ | Data transfer management |
| **GridFTP Module** | C/Globus | Custom authorization for data access |
| **Python Client** | Python | API + CLI |

### Architecture in One Diagram

```
User → [Web UI/CLI/Python] → Web Service → Core Service → [Database + Repos] → Storage
                                    ↓
                              Globus Transfer API
```

## Quick Setup

### Prerequisites

```bash
# Ubuntu/Debian
sudo apt-get install build-essential cmake git \
    libssl-dev libcurl4-openssl-dev libboost-all-dev \
    nodejs npm python3 python3-pip
```

### Build & Run (Development)

```bash
# 1. Clone
git clone https://github.com/ORNL/DataFed.git
cd DataFed

# 2. Configure
./scripts/generate_datafed.sh
source config/datafed.sh

# 3. Install dependencies
./scripts/install_dependencies.sh

# 4. Build
mkdir build && cd build
cmake -DBUILD_CORE_SERVER=ON \
      -DBUILD_WEB_SERVER=ON \
      -DBUILD_PYTHON_CLIENT=ON ..
make -j$(nproc)

# 5. Run (in separate terminals)
# Terminal 1: Database
docker run -p 8529:8529 -e ARANGO_ROOT_PASSWORD=test arangodb:3.12

# Terminal 2: Core service
./build/core/server/datafed-core --cfg config/core.conf

# Terminal 3: Web service
cd web && npm install
node datafed-ws.js config/web.conf
```

### Docker Compose (Fastest)

```bash
cd compose/metadata
./generate_env.sh
docker-compose up
```

Access at: http://localhost:8080

## Key Directories

```
DataFed/
├── core/server/          → Core service (C++)
├── web/                  → Web service (Node.js) + frontend
├── core/database/foxx/   → Database layer (JavaScript)
├── repository/           → Repository service (C++)
├── python/datafed_pkg/   → Python client
├── common/               → Shared C++ code
├── scripts/              → Installation scripts
└── tests/                → Tests
```

## Common Development Tasks

### Add New API Endpoint

1. **Define protobuf** (`common/proto/common/SDMS_Auth.proto`):
   ```protobuf
   message MyRequest { required string param = 1; }
   message MyReply { repeated ResultData data = 1; }
   ```

2. **Implement in Core** (`core/server/ClientWorker.cpp`):
   ```cpp
   void ClientWorker::procMyRequest(const MyRequest &req, MyReply &reply) {
       // Business logic
   }
   ```

3. **Add Foxx handler** (`core/database/foxx/api/router.js`):
   ```javascript
   router.post('/my_endpoint', (req, res) => {
       const result = processRequest(req.body);
       res.json(result);
   });
   ```

4. **Add Web endpoint** (`web/datafed-ws.js`):
   ```javascript
   app.post('/api/my/endpoint', (req, res) => {
       sendMessage('MyRequest', req.body, req, res, reply => res.json(reply));
   });
   ```

5. **Add Python method** (`python/datafed_pkg/datafed/CommandLib.py`):
   ```python
   def myMethod(self, param):
       msg = auth.MyRequest(param=param)
       return self._mapi.sendMessage('MyRequest', msg)
   ```

### Run Tests

```bash
# All tests
cd build && ctest --output-on-failure

# Specific suite
ctest -R unit_tests_common
ctest -R end_to_end_api

# Python tests
cd tests/end-to-end && pytest -v

# Web tests
cd web && npm test
```

### Debug a Service

```bash
# Enable debug logging
export DATAFED_LOG_LEVEL=DEBUG

# Run in foreground
./datafed-core --cfg core.conf --log-level debug

# Check logs
journalctl -u datafed-core -f
tail -f /var/log/datafed/core.log
```

## Technology Cheat Sheet

### Communication

| Layer | Protocol | Usage |
|-------|----------|-------|
| Inter-service | ZeroMQ (DEALER-ROUTER) | Core ↔ Web, Core ↔ Repo |
| Serialization | Protocol Buffers | All messages |
| Database | HTTP/REST | Core ↔ Foxx |
| Data Transfer | Globus API | File transfers |

### Message Flow Example

```
1. User clicks "Create Record" in Web UI
   ↓ AJAX POST to /api/dat/create
2. Web Service receives request
   ↓ Validates session
   ↓ Serializes protobuf RecordCreateRequest
   ↓ Sends via ZeroMQ to Core
3. Core Service receives message
   ↓ Deserializes protobuf
   ↓ Authenticates/authorizes
   ↓ Sends HTTP POST to Foxx
4. Foxx processes request
   ↓ Inserts into ArangoDB
   ↓ Returns JSON
5. Core serializes protobuf reply
   ↓ Sends via ZeroMQ to Web
6. Web sends JSON to browser
```

### Database Quick Reference

```javascript
// Collections
u  - users
d  - data records  
c  - collections
p  - projects
repo - repositories
task - transfer tasks
acl - access control

// Edges
owner - ownership (u → d/c/p)
item - collection membership (c → d/c)
dep - dependencies (d → d)
acl - grants (u/p → d/c)
```

### Python API Quick Examples

```python
from datafed import CommandLib as df

api = df.API()

# Login
api.loginByPassword("user", "pass")

# Create record
rec = api.dataCreate(title="My Data", metadata='{"key":"value"}')

# Upload file
api.dataPut(rec.data[0].id, "/path/to/file", wait=True)

# Search
results = api.dataSearch(query="keywords", count=20)

# Create collection
coll = api.collectionCreate(title="My Collection")
api.collectionItemsUpdate(coll.coll[0].id, add_ids=[rec.data[0].id])
```

### CLI Quick Examples

```bash
# Login
datafed setup  # Interactive setup

# Create record
datafed data create --title "My Data" --metadata '{"key":"value"}'

# Upload
datafed data put d/12345 /path/to/file --wait

# Download
datafed data get d/12345 /destination/ --wait

# Search
datafed data search --query "keywords" --count 20

# Collections
datafed coll create --title "Collection"
datafed coll link c/12345 d/67890
```

## Configuration Files

### Core Service (`core.conf`)

```ini
[server]
port = 7512
cred_dir = /etc/datafed/keys

[database]
url = http://localhost:8529
user = root
password = yourpassword

[globus]
client_id = your-client-id
client_secret = your-secret
```

### Web Service (`web.conf`)

```ini
[server]
host = localhost
port = 8080
extern_url = http://localhost:8080
session_secret = generate-random-secret

[oauth]
client_id = your-globus-client-id
client_secret = your-globus-secret

[core]
server_address = tcp://localhost:7512
```

## Troubleshooting

### Build Fails

```bash
# Clean rebuild
rm -rf build/
./scripts/install_dependencies.sh
mkdir build && cd build && cmake .. && make -j$(nproc)
```

### Service Won't Start

```bash
# Check dependencies
curl http://localhost:8529/_api/version  # Database
netstat -tuln | grep 7512                # Core service

# Check config
cat config/datafed.sh
source config/datafed.sh
```

### Authentication Fails

```bash
# Verify Globus credentials
echo $GLOBUS_CLIENT_ID
echo $GLOBUS_CLIENT_SECRET

# Check session secret
grep session_secret config/web.conf
```

### Transfer Fails

```bash
# Check Globus endpoint
globus endpoint show $ENDPOINT_ID

# Verify endpoint is activated
globus endpoint is-activated $ENDPOINT_ID
```

## Useful Commands

```bash
# View service status
systemctl status datafed-core
systemctl status datafed-web

# Watch logs
journalctl -u datafed-core -f

# Clear test database
./scripts/clear_db.sh

# Restart services
sudo systemctl restart datafed-core
sudo systemctl restart datafed-web

# Check versions
./build/core/server/datafed-core --version
node --version
python3 --version
```

## Resources

- **Full Developer Guide**: [DEVELOPER_GUIDE.md](DEVELOPER_GUIDE.md)
- **Documentation**: https://ornl.github.io/DataFed/
- **Repository**: https://github.com/ORNL/DataFed
- **Issues**: https://github.com/ORNL/DataFed/issues

## Next Steps

1. ✅ Read this quick start
2. 📖 Review the full [Developer Guide](DEVELOPER_GUIDE.md)
3. 🔧 Set up development environment
4. ✨ Try adding a simple feature
5. 🧪 Run the test suite
6. 🚀 Build something awesome!

---

**Need help?** Open an issue on GitHub or check the full developer guide for detailed information.

