# DataFed Developer Documentation

Welcome to the DataFed developer documentation! This README provides an overview of all available developer resources and guides you to the right documentation for your needs.

## 📚 Documentation Index

### 🚀 [Quick Start Guide](QUICK_START.md)
**Perfect for: New developers, quick reference**

A concise guide that gets you up and running quickly. Includes:
- 5-minute system overview
- Quick setup instructions (build & Docker)
- Common development tasks with code examples
- Technology cheat sheet
- Troubleshooting tips

👉 **Start here** if you want to begin developing immediately.

### 📖 [Developer Guide](DEVELOPER_GUIDE.md)
**Perfect for: In-depth understanding, comprehensive reference**

A detailed, comprehensive guide covering every aspect of DataFed development. Includes:
- Complete system architecture explanation
- Technology stack details
- Full project structure breakdown
- Core component deep-dives (Core, Web, Database, Repository, Python)
- Communication protocols (ZeroMQ, Protobuf, REST)
- Build system documentation
- Development workflow and best practices
- Testing strategies
- Deployment guide with configuration examples
- Complete API reference (Python, REST, CLI)

👉 **Read this** for comprehensive understanding of the codebase.

### 🏗️ [Architecture Reference](ARCHITECTURE.md)
**Perfect for: Visual learners, system design understanding**

Visual architectural documentation with detailed diagrams:
- System overview diagrams
- Component architecture (Core, Web, Repo services)
- Data flow diagrams (auth, record creation, transfers)
- Communication patterns (ZeroMQ, Protobuf)
- Database schema with graph relationships
- Deployment topologies (dev, small production, HA)

👉 **Consult this** for visual understanding of system design.

## 🎯 Documentation Roadmap

### I'm a new developer, where do I start?

```
1. Read: Quick Start Guide (30 min)
   ↓
2. Setup: Follow build instructions
   ↓
3. Explore: Run the system and browse code
   ↓
4. Deep Dive: Read Developer Guide sections as needed
   ↓
5. Reference: Use Architecture diagrams to understand flows
```

### I want to add a feature

```
1. Quick Start → "Add New API Endpoint" section
   ↓
2. Developer Guide → "Adding New Features" section
   ↓
3. Architecture → Review relevant flow diagrams
   ↓
4. Developer Guide → "API Reference" for similar examples
```

### I'm debugging an issue

```
1. Quick Start → "Troubleshooting" section
   ↓
2. Developer Guide → Component-specific architecture
   ↓
3. Architecture → Data flow diagrams
   ↓
4. Source code + inline documentation
```

### I'm deploying DataFed

```
1. Developer Guide → "Deployment" section
   ↓
2. Architecture → "Deployment Topologies"
   ↓
3. scripts/ directory → Installation scripts
   ↓
4. compose/ directory → Docker Compose examples
```

## 📋 Quick Reference

### Essential Files

| File | Purpose |
|------|---------|
| `QUICK_START.md` | Quick reference for common tasks |
| `DEVELOPER_GUIDE.md` | Comprehensive development guide |
| `ARCHITECTURE.md` | Visual architecture documentation |
| `README.md` | Project overview (original) |
| `BUILD.md` | Build instructions |
| `CHANGELOG.md` | Version history and changes |

### Key Directories

| Directory | Contents |
|-----------|----------|
| `core/server/` | Core service (C++) |
| `web/` | Web service (Node.js) + frontend |
| `core/database/foxx/` | Database layer (ArangoDB Foxx) |
| `repository/` | Repository service (C++) |
| `python/datafed_pkg/` | Python client library |
| `common/` | Shared C++ code |
| `scripts/` | Installation and utility scripts |
| `tests/` | Test suites |
| `compose/` | Docker Compose configurations |
| `docs/` | Built documentation (Sphinx) |

### Technology Stack Summary

| Component | Technology |
|-----------|-----------|
| Core Service | C++17, ZeroMQ, Protobuf |
| Web Service | Node.js, Express, ECT templates |
| Database | ArangoDB + Foxx (JavaScript) |
| Repository | C++, Globus GridFTP |
| Python Client | Python 3.8+, ZeroMQ, Protobuf |
| Build System | CMake 3.17+ |
| Data Transfer | Globus Transfer API |

## 🔗 External Resources

### Official Links
- **Documentation**: https://ornl.github.io/DataFed/
- **Repository**: https://github.com/ORNL/DataFed
- **Issues**: https://github.com/ORNL/DataFed/issues

### Related Documentation
- **Globus**: https://docs.globus.org/
- **ArangoDB**: https://www.arangodb.com/docs/
- **ZeroMQ**: https://zguide.zeromq.org/
- **Protocol Buffers**: https://developers.google.com/protocol-buffers

## 💡 Quick Examples

### Create a Data Record (Python)

```python
from datafed import CommandLib as df

api = df.API()
api.loginByPassword("user", "password")

record = api.dataCreate(
    title="My Dataset",
    metadata='{"experiment": "test001"}'
)
print(f"Created: {record.data[0].id}")
```

### Upload Data (CLI)

```bash
datafed data create --title "My Dataset"
datafed data put d/12345 /path/to/file --wait
```

### Query Database (Foxx)

```javascript
// In core/database/foxx/api/
const records = db._query(aql`
    FOR d IN d
    FILTER d.owner == ${userId}
    LIMIT 10
    RETURN d
`).toArray();
```

### Send Message to Core (Web Service)

```javascript
// In web/datafed-ws.js
app.get('/api/dat/view', (req, res) => {
    sendMessage(
        'RecordViewRequest',
        { id: req.query.id },
        req, res,
        (reply) => res.json(reply)
    );
});
```

## 🛠️ Development Workflow

### Initial Setup

```bash
# 1. Clone and configure
git clone https://github.com/ORNL/DataFed.git
cd DataFed
./scripts/generate_datafed.sh

# 2. Install dependencies
./scripts/install_dependencies.sh

# 3. Build
mkdir build && cd build
cmake .. -DBUILD_CORE_SERVER=ON \
         -DBUILD_WEB_SERVER=ON \
         -DBUILD_PYTHON_CLIENT=ON
make -j$(nproc)

# 4. Run tests
ctest --output-on-failure
```

### Daily Development

```bash
# Start services (separate terminals)
docker-compose -f compose/metadata/compose.yml up  # Database
./build/core/server/datafed-core --cfg config/core.conf
cd web && node datafed-ws.js config/web.conf

# Make changes, rebuild affected components
cd build
make <target>

# Run specific tests
ctest -R test_name

# Check logs
journalctl -u datafed-core -f
```

### Code Style

- **C++**: Follow existing patterns, use `m_` prefix for members
- **JavaScript**: ES6 modules, consistent naming conventions
- **Python**: PEP 8, type hints where applicable
- **Documentation**: Update guides when adding features

## 🧪 Testing

### Test Types

| Type | Location | Command |
|------|----------|---------|
| C++ Unit Tests | `common/tests/unit/` | `ctest -R unit_tests_common` |
| Foxx Tests | `core/database/foxx/tests/` | `ctest -R unit_tests_foxx` |
| Web Tests | `web/test/` | `cd web && npm test` |
| Python Tests | `python/datafed_pkg/test/` | `pytest` |
| End-to-End | `tests/end-to-end/` | `ctest -R end_to_end` |

### Running All Tests

```bash
cd build
ctest --output-on-failure -j8
```

## 🚢 Deployment

### Docker Compose (Recommended for Dev)

```bash
cd compose/metadata
./generate_env.sh
docker-compose up
```

### Manual Installation

```bash
# Core service
./scripts/install_core.sh
sudo systemctl start datafed-core

# Web service
./scripts/install_ws.sh
sudo systemctl start datafed-web

# Repository service (with Globus)
./scripts/install_repo.sh
sudo systemctl start datafed-repo
```

See [Developer Guide - Deployment](DEVELOPER_GUIDE.md#deployment) for detailed instructions.

## 🐛 Common Issues

### Build fails with protobuf errors
```bash
rm -rf build/
./scripts/install_dependencies.sh
```

### Service won't start
```bash
# Check dependencies
curl http://localhost:8529/_api/version
netstat -tuln | grep 7512
```

### Authentication fails
```bash
# Verify Globus credentials in config
grep client_id config/web.conf
```

See [Quick Start - Troubleshooting](QUICK_START.md#troubleshooting) for more solutions.

## 📊 Project Statistics

### Languages
- C++: ~50,000 lines (Core, Repository services)
- JavaScript: ~30,000 lines (Web service, Foxx, Frontend)
- Python: ~15,000 lines (Client library)
- Protocol Buffers: ~1,000 lines (Message definitions)

### Components
- 6 main services (Core, Web, Database, Repo, GridFTP, Python Client)
- 100+ Protocol Buffer message types
- 200+ API endpoints
- 50+ Database collections and edges

## 🤝 Contributing

1. **Understand the system**: Read Quick Start and Developer Guide
2. **Set up environment**: Follow setup instructions
3. **Find or create an issue**: Check GitHub issues
4. **Make changes**: Follow code style guidelines
5. **Test thoroughly**: Run all relevant tests
6. **Update documentation**: Keep guides in sync
7. **Submit PR**: Include clear description and tests

## 📞 Getting Help

- **GitHub Issues**: https://github.com/ORNL/DataFed/issues
- **Documentation**: https://ornl.github.io/DataFed/
- **Developer Guides**: This repository

## 📝 Version Information

DataFed uses semantic versioning with calendar-based releases:
- **Release**: `YEAR.MONTH.DAY.HOUR.MINUTE`
- **API**: `MAJOR.MINOR.PATCH`

Check `CHANGELOG.md` for version history.

---

## What's Next?

1. ✅ **Start with**: [Quick Start Guide](QUICK_START.md)
2. 📖 **Deep dive into**: [Developer Guide](DEVELOPER_GUIDE.md)  
3. 🏗️ **Visualize with**: [Architecture Reference](ARCHITECTURE.md)
4. 💻 **Build something amazing!**

---

**Last Updated**: 2024 (check git history for latest changes)

**Maintainers**: DataFed Development Team @ ORNL

**License**: See LICENSE.md

