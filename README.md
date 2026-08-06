# SQL-ToolKit

[![SQL Server](https://img.shields.io/badge/SQL%20Server-2008%2B-blue.svg)](https://www.microsoft.com/en-us/sql-server/sql-server-downloads)
[![Windows](https://img.shields.io/badge/Windows-10%2B-lightgrey.svg)](https://www.microsoft.com/en-us/windows)

A comprehensive toolkit for SQL Server Database Administrators and Developers, featuring diagnostic scripts, maintenance procedures, automation tools, and practical examples.

## Overview

This repository contains a curated collection of tools and scripts designed to simplify SQL Server management tasks. Whether you're performing routine maintenance, troubleshooting performance issues, or automating deployments, SQL-ToolKit provides practical solutions validated by real-world DBA experience.

## Project Structure

```
SQL-ToolKit/
├── By Hossam/          # Custom SQL and PowerShell scripts
│   ├── PowerShell/     # Infrastructure automation scripts
│   ├── SQL/           # Database maintenance and utility scripts
│
├── FirstResponderKit/  # Brent Ozar's First Responder Kit
│   ├── Final/         # Production-ready diagnostic scripts
│   ├── adhoc/         # Quick diagnostic queries
│   └── Deprecated/    # Legacy script versions
│
├── Misc/              # Miscellaneous utilities and snippets
│   ├── 2021/         # 2021 versions of various scripts
│   ├── Daily Checks/ # Routine health check scripts
│   └── Queries/      # Utility queries and lookups
│
└── Projects/          # Sample projects and implementations
```

## Getting Started

1. **Clone the repository:**
   ```bash
   git clone https://github.com/hossamaladdin/SQL-ToolKit.git
   ```

2. **Choose your tools based on needs:**
   - For performance diagnostics → FirstResponderKit
   - For maintenance automation → By Hossam/PowerShell
   - For emergency troubleshooting → FirstResponderKit/sp_BlitzFirst

### Installation Instructions

#### FirstResponderKit (Prerequisites: SQL Server 2012+)
Run one of the installation scripts in `FirstResponderKit/` in your master database:
- Use `Install-Core-Blitz-No-Query-Store.sql` for basic installation
- Use `Install-Core-Blitz-With-Query-Store.sql` for SQL Server 2019+ with Query Store capability

#### Custom Scripts (By Hossam)
- PowerShell scripts: Ensure Execution Policy allows running scripts
- SQL scripts: Execute in appropriate databases with sufficient permissions

## Categories

### Performance Diagnostics (FirstResponderKit)
- **sp_Blitz**: Overall server health check with prioritized recommendations
- **sp_BlitzCache**: Top resource-intensive queries analysis
- **sp_BlitzFirst**: Real-time performance diagnostics
- **sp_BlitzIndex**: Index usage and optimization recommendations
- **sp_BlitzWho**: Current session activity monitoring
- **sp_BlitzLock**: Deadlock analysis and history
- **sp_BlitzQueryStore**: Query Store analysis (SQL Server 2016+)

### Database Maintenance (By Hossam/SQL)
- Backup and restore automation scripts
- Login and permission management
- Service account configuration
- Security certificates management
- Index maintenance utilities
- Database integrity checks
- Mail configuration setup

### Infrastructure Automation (By Hossam/PowerShell)
- Server health monitoring
- Automated certificate renewal
- SQL Server upgrades
- Service monitoring and alerting
- Batch processing utilities

### Utility Scripts (Misc)
- Daily health check routines
- Backup verification
- Log shipping monitors
- Database size analysis
- Failed job alerts
- High availability setup

### Sample Projects (Projects)
- SQL Dashboard implementations
- Express Edition tools
- Monitoring dashboard templates
- CNC system integration examples

## Key Features

### Comprehensive Diagnostics
- Multi-level performance analysis (server, database, query)
- Automated issue prioritization
- Historical trend analysis
- Real-time monitoring tools

### Automation Ready
- Scheduled maintenance scripts
- Automated deployment procedures
- Alert configuration
- Backup validation routines

### Security Focused
- Encrypted credential handling
- Secure script execution guidelines
- Permission management utilities
- Audit and compliance scripts

### Cross-Version Support
- SQL Server 2008 through 2022
- Windows and Linux deployments
- Different editions support

## Common Use Cases

### New Server Setup
1. Run FirstResponderKit install scripts
2. Execute baseline health checks with sp_Blitz
3. Configure backups using Ola Hallengren scripts (integrated)
4. Set up alerting and monitoring

### Performance Emergency
1. Execute `sp_BlitzFirst @ExpertMode = 1` for immediate diagnostics
2. Check `sp_BlitzCache` for query killers
3. Analyze with `sp_BlitzIndex` for index recommendations
4. Generate action plan based on prioritized findings

### Maintenance Routine
1. Daily checks using scripts from Misc/Daily Checks/
2. Weekly `sp_Blitz` full scans
3. Monthly index analysis with `sp_BlitzIndex @Mode = 2`
4. Automated backup verification

### Troubleshooting Queries
1. Use adhoc queries in FirstResponderKit/adhoc/ for quick inspections
2. Generate detailed reports with sp_BlitzCache parameters
3. Archive diagnostic data using logging features

## Best Practices

### Execution Permissions
- Install diagnostic tools in master with sysadmin access
- Local DBA tools can run with reduced permissions
- Production script execution should have proper monitoring

### Version Control
- Keep scripts versioned in your own repositories
- Test in non-production before enterprise deployment
- Document customizations and modifications

### Monitoring Integration
- Centralize outputs to dedicated DBA databases
- Implement alerting on critical findings
- Build dashboards for key metrics visualization

### Performance Considerations
- Limit large table scans during business hours
- Use sampling options for massive databases
- Schedule intensive diagnostics for off-peak periods

## Integration Options

### Third-Party Tools
- Ola Hallengren's Maintenance Solution (complementary)
- Redgate SQL Monitor and other monitoring platforms
- Custom CMS, SCOM, and alert systems

### Corporate Environments
- Excel export for stakeholder reporting
- PowerShell automation for DevOps pipelines
- REST API integrations where supported

## Contributing

This toolkit evolves through community contributions and field experience. When contributing:
- Test thoroughly in development environments
- Document parameter usage and edge cases
- Follow naming conventions established
- Include error handling and logging

## Support

### Community Resources
- SQL Server Central forums
- Brent Ozar Unlimited blog and training
- Local SQL Server user groups

### Learning Path
- Start with FirstResponderKit sp_Blitz family
- Progress to automated scripts in By Hossam section
- Customize Misc scripts for your environment
- Build your own tools using Projects as templates

---

