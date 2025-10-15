# DataFed Documentation Index

## 📖 Complete Documentation Suite

This directory contains comprehensive developer documentation for the DataFed federated scientific data management system. Choose the documentation that best fits your needs:

---

## 🎯 Start Here

### 1. [**DEVELOPER_README.md**](DEVELOPER_README.md) 📋
**Your documentation roadmap and entry point**

- Overview of all documentation
- Navigation guide based on your goals
- Quick reference tables
- Project statistics
- Getting started checklist

**When to use**: First time here? Start with this file.

---

## 📚 Main Documentation

### 2. [**QUICK_START.md**](QUICK_START.md) 🚀
**Fast-track guide for developers**

- 5-minute system overview
- Quick setup (build & Docker)
- Common tasks with code examples
- Technology cheat sheet
- Troubleshooting guide
- **~200 lines**, read time: 15-20 minutes

**When to use**: 
- You want to start coding immediately
- You need a quick reference
- You're looking for common solutions

---

### 3. [**DEVELOPER_GUIDE.md**](DEVELOPER_GUIDE.md) 📖
**Comprehensive development manual**

- **1000+ lines** of detailed documentation
- System architecture (all components)
- Technology stack deep-dive
- Complete project structure
- Core components explained
- Communication protocols
- Build system guide
- Development workflow
- Testing strategies
- Deployment instructions
- Full API reference (Python, REST, CLI)
- **~1000 lines**, read time: 2-3 hours

**When to use**:
- You need in-depth understanding
- You're implementing new features
- You want comprehensive reference
- You're debugging complex issues

---

### 4. [**ARCHITECTURE.md**](ARCHITECTURE.md) 🏗️
**Visual architecture reference**

- System overview diagrams
- Component internal architecture
- Data flow diagrams (auth, CRUD, transfers)
- Communication patterns (ZeroMQ, Protobuf)
- Database schema with relationships
- Deployment topologies
- Network diagrams
- **~500 lines**, rich in ASCII diagrams

**When to use**:
- You're a visual learner
- You need to understand system design
- You're planning architecture changes
- You're debugging data flows

---

## 📂 Documentation by Topic

### Getting Started
1. **DEVELOPER_README.md** → Documentation overview
2. **QUICK_START.md** → Setup & first steps
3. **DEVELOPER_GUIDE.md** → Section: "Development Workflow"

### Understanding the System
1. **ARCHITECTURE.md** → System diagrams
2. **DEVELOPER_GUIDE.md** → Section: "System Architecture"
3. **DEVELOPER_GUIDE.md** → Section: "Core Components"

### Adding Features
1. **QUICK_START.md** → "Add New API Endpoint"
2. **DEVELOPER_GUIDE.md** → Section: "Adding New Features"
3. **ARCHITECTURE.md** → Relevant flow diagrams

### API Development
1. **DEVELOPER_GUIDE.md** → Section: "API Reference"
2. **QUICK_START.md** → API examples
3. **ARCHITECTURE.md** → Communication patterns

### Testing
1. **DEVELOPER_GUIDE.md** → Section: "Testing"
2. **QUICK_START.md** → Common test commands
3. **tests/** directory → Test code

### Deployment
1. **DEVELOPER_GUIDE.md** → Section: "Deployment"
2. **ARCHITECTURE.md** → Deployment topologies
3. **compose/** directory → Docker configs
4. **scripts/** directory → Install scripts

### Database
1. **ARCHITECTURE.md** → Database schema
2. **DEVELOPER_GUIDE.md** → Section: "Database Layer"
3. **core/database/foxx/** → Foxx code

### Troubleshooting
1. **QUICK_START.md** → Troubleshooting section
2. **DEVELOPER_GUIDE.md** → Component-specific issues
3. **DEVELOPER_GUIDE.md** → Appendix: Common Issues

---

## 🔍 Find Information By...

### By Role

**New Developer:**
```
DEVELOPER_README.md → QUICK_START.md → ARCHITECTURE.md → DEVELOPER_GUIDE.md (as needed)
```

**API Developer:**
```
QUICK_START.md (API examples) → DEVELOPER_GUIDE.md (API Reference) → Source code
```

**Frontend Developer:**
```
ARCHITECTURE.md (Web Service) → DEVELOPER_GUIDE.md (Web Service) → web/static/
```

**Backend Developer:**
```
ARCHITECTURE.md (Core/Repo) → DEVELOPER_GUIDE.md (Core Components) → core/server/
```

**DevOps Engineer:**
```
DEVELOPER_GUIDE.md (Deployment) → ARCHITECTURE.md (Topologies) → scripts/ + compose/
```

### By Technology

**C++ (Core/Repo):**
- DEVELOPER_GUIDE.md → "Core Service (C++)"
- ARCHITECTURE.md → "Core Service Internal Architecture"
- Source: `core/server/`, `repository/`

**Node.js (Web):**
- DEVELOPER_GUIDE.md → "Web Service (Node.js/Express)"
- ARCHITECTURE.md → "Web Service Architecture"
- Source: `web/`

**JavaScript (Database/Frontend):**
- DEVELOPER_GUIDE.md → "Database Layer (ArangoDB + Foxx)"
- ARCHITECTURE.md → "Database Schema"
- Source: `core/database/foxx/`, `web/static/`

**Python (Client):**
- DEVELOPER_GUIDE.md → "Python Client"
- QUICK_START.md → Python examples
- Source: `python/datafed_pkg/`

**Protocol Buffers:**
- DEVELOPER_GUIDE.md → "Protocol Buffers"
- ARCHITECTURE.md → "Communication Patterns"
- Source: `common/proto/`

**ZeroMQ:**
- ARCHITECTURE.md → "ZeroMQ Message Structure"
- DEVELOPER_GUIDE.md → "ZeroMQ Messaging"

### By Task

**Building the project:**
```
QUICK_START.md → Build section
DEVELOPER_GUIDE.md → Build System
CMakeLists.txt
```

**Running tests:**
```
QUICK_START.md → Run Tests
DEVELOPER_GUIDE.md → Testing section
ctest commands
```

**Adding API endpoint:**
```
QUICK_START.md → "Add New API Endpoint"
DEVELOPER_GUIDE.md → "Adding New Features"
Existing code examples
```

**Deploying:**
```
DEVELOPER_GUIDE.md → Deployment section
ARCHITECTURE.md → Deployment Topologies
compose/ directory
```

**Understanding data flow:**
```
ARCHITECTURE.md → Data Flow Diagrams
DEVELOPER_GUIDE.md → Communication Protocols
Source code
```

---

## 📊 Documentation Coverage

### What's Documented

✅ System architecture and components  
✅ Technology stack and dependencies  
✅ Build and configuration  
✅ Development workflow  
✅ Testing strategies  
✅ Deployment options  
✅ API reference (Python, REST, CLI)  
✅ Database schema  
✅ Communication protocols  
✅ Common issues and solutions  

### Additional Resources

- **Original README.md** - Project overview
- **BUILD.md** - Build instructions
- **CHANGELOG.md** - Version history
- **docs/** - Sphinx documentation (HTML)
- **doc_source/** - Documentation source (RST)
- Source code inline comments

---

## 🗺️ Learning Paths

### Path 1: Quick Start (1-2 hours)
```
1. DEVELOPER_README.md (10 min)
2. QUICK_START.md (20 min)
3. Setup environment (30 min)
4. Run example code (30 min)
```

### Path 2: Full Understanding (1 day)
```
1. DEVELOPER_README.md (10 min)
2. QUICK_START.md (20 min)
3. ARCHITECTURE.md (1 hour)
4. DEVELOPER_GUIDE.md - All sections (3 hours)
5. Explore source code (3 hours)
```

### Path 3: Specific Feature Development (2-3 hours)
```
1. QUICK_START.md - Relevant section (10 min)
2. ARCHITECTURE.md - Flow diagrams (20 min)
3. DEVELOPER_GUIDE.md - Component guide (30 min)
4. Study similar code (1 hour)
5. Implement and test (1 hour)
```

---

## 📝 Documentation Files Summary

| File | Lines | Read Time | Purpose |
|------|-------|-----------|---------|
| **DEVELOPER_README.md** | ~350 | 20 min | Entry point, navigation guide |
| **QUICK_START.md** | ~200 | 15 min | Quick reference, common tasks |
| **DEVELOPER_GUIDE.md** | ~1000 | 2-3 hours | Comprehensive reference |
| **ARCHITECTURE.md** | ~500 | 1 hour | Visual architecture guide |

**Total**: ~2000+ lines of developer documentation

---

## 🎯 Quick Links

### Most Common Needs

- **Setup Instructions**: [QUICK_START.md](QUICK_START.md#quick-setup)
- **API Examples**: [QUICK_START.md](QUICK_START.md#quick-examples)
- **Architecture Diagrams**: [ARCHITECTURE.md](ARCHITECTURE.md)
- **Component Details**: [DEVELOPER_GUIDE.md](DEVELOPER_GUIDE.md#core-components)
- **Deployment Guide**: [DEVELOPER_GUIDE.md](DEVELOPER_GUIDE.md#deployment)
- **Troubleshooting**: [QUICK_START.md](QUICK_START.md#troubleshooting)

### External Resources

- **Project Site**: https://ornl.github.io/DataFed/
- **Repository**: https://github.com/ORNL/DataFed
- **Issues**: https://github.com/ORNL/DataFed/issues

---

## 🚀 Start Your Journey

**Choose your path:**

1. **I'm brand new** → Start with [DEVELOPER_README.md](DEVELOPER_README.md)
2. **I want to code now** → Jump to [QUICK_START.md](QUICK_START.md)
3. **I need deep knowledge** → Read [DEVELOPER_GUIDE.md](DEVELOPER_GUIDE.md)
4. **I'm visual** → Browse [ARCHITECTURE.md](ARCHITECTURE.md)

---

**Happy coding! 🎉**

*Last updated: Check git history for latest changes*

