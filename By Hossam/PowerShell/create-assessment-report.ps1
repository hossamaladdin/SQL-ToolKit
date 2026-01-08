# Create Word Assessment Report from Excel Data
$wordPath = "C:\Users\hossam.aladdin\Documents\SQL Server Environment Assessment Report.docx"

# Create Word application
$word = New-Object -ComObject Word.Application
$word.Visible = $false
$doc = $word.Documents.Add()
$selection = $word.Selection

# Set default font
$selection.Font.Name = "Calibri"
$selection.Font.Size = 11

# Title
$selection.Font.Size = 20
$selection.Font.Bold = $true
$selection.Font.Color = 0x0000FF  # Red
$selection.TypeText("SQL Server Environment Assessment Report")
$selection.TypeParagraph()

$selection.Font.Size = 11
$selection.Font.Bold = $false
$selection.Font.Color = 0x000000  # Black
$selection.TypeText("Assessment Date: January 9, 2026")
$selection.TypeParagraph()
$selection.TypeText("Prepared by: Database Administration Team")
$selection.TypeParagraph()
$selection.TypeParagraph()

# Executive Summary Section
$selection.Font.Size = 16
$selection.Font.Bold = $true
$selection.Font.Color = 0x0000FF  # Red
$selection.TypeText("EXECUTIVE SUMMARY")
$selection.TypeParagraph()

$selection.Font.Size = 11
$selection.Font.Bold = $false
$selection.Font.Color = 0x000000

# Summary Table
$table1 = $selection.Tables.Add($selection.Range, 4, 2)
$table1.Style = "Grid Table 4 - Accent 1"
$table1.Cell(1,1).Range.Text = "Servers Assessed"
$table1.Cell(1,2).Range.Text = "8"
$table1.Cell(2,1).Range.Text = "Total Critical Issues"
$table1.Cell(2,2).Range.Text = "12"
$table1.Cell(3,1).Range.Text = "Total Warnings"
$table1.Cell(3,2).Range.Text = "45"
$table1.Cell(4,1).Range.Text = "Risk Level"
$table1.Cell(4,2).Range.Text = "HIGH - Immediate Action Required"

$selection.EndOf(15) | Out-Null  # wdStory
$selection.MoveDown() | Out-Null
$selection.TypeParagraph()

# Risk Distribution
$selection.Font.Bold = $true
$selection.TypeText("Risk Distribution by Server")
$selection.TypeParagraph()
$selection.Font.Bold = $false

$table2 = $selection.Tables.Add($selection.Range, 4, 2)
$table2.Style = "Grid Table 4 - Accent 1"
$table2.Cell(1,1).Range.Text = "Risk Level"
$table2.Cell(1,2).Range.Text = "Servers"
$table2.Cell(2,1).Range.Text = "HIGH RISK (Immediate)"
$table2.Cell(2,2).Range.Text = "Saaed360-SQL-7 (7 critical), SaaedEVGSQL4 (2 critical)"
$table2.Cell(3,1).Range.Text = "MEDIUM RISK (7 days)"
$table2.Cell(3,2).Range.Text = "PR-VM-BI360-N1, SAAEDEVGSQL3, ImpoundYard-DB"
$table2.Cell(4,1).Range.Text = "LOW RISK (Monitored)"
$table2.Cell(4,2).Range.Text = "Saaed360-SQL-3, SaaedAPPSQL-01, SaaedAPPSQL-02"

$selection.EndOf(15) | Out-Null
$selection.MoveDown() | Out-Null
$selection.TypeParagraph()

# Critical Issues Section
$selection.Font.Size = 16
$selection.Font.Bold = $true
$selection.Font.Color = 0x0000FF
$selection.TypeText("CRITICAL ISSUES - IMMEDIATE ACTION REQUIRED")
$selection.TypeParagraph()

$selection.Font.Size = 11
$selection.Font.Bold = $false
$selection.Font.Color = 0x000000

# Issue 1
$selection.Font.Bold = $true
$selection.TypeText("1. SaaedEVGSQL4 - CRITICAL DISK SPACE (8.38% Free)")
$selection.TypeParagraph()
$selection.Font.Bold = $false
$selection.TypeText("    * Impact: Database operations will FAIL when disk fills")
$selection.TypeParagraph()
$selection.TypeText("    * Status: Only 21 GB free on E:\ (256 GB drive)")
$selection.TypeParagraph()
$selection.TypeText("    * Action: Immediately free up disk space or expand drive")
$selection.TypeParagraph()
$selection.TypeText("    * Priority: CRITICAL - WITHIN 24 HOURS")
$selection.TypeParagraph()
$selection.TypeParagraph()

# Issue 2
$selection.Font.Bold = $true
$selection.TypeText("2. SaaedEVGSQL4 - CRITICAL PAGE LIFE EXPECTANCY")
$selection.TypeParagraph()
$selection.Font.Bold = $false
$selection.TypeText("    * Current PLE: 115 seconds (Normal: >300 seconds)")
$selection.TypeParagraph()
$selection.TypeText("    * Impact: Severe memory pressure causing performance degradation")
$selection.TypeParagraph()
$selection.TypeText("    * Cause: Database size (3.8 TB) exceeds available memory (7 GB)")
$selection.TypeParagraph()
$selection.TypeText("    * Action: Add more memory or optimize queries")
$selection.TypeParagraph()
$selection.TypeParagraph()

# Issue 3
$selection.Font.Bold = $true
$selection.TypeText("3. SaaedEVGSQL4 - MASSIVE LOG FILE WITH PERCENTAGE GROWTH")
$selection.TypeParagraph()
$selection.Font.Bold = $false
$selection.TypeText("    * Log File Size: 95,523 GB (95.5 TB) with 10% autogrowth")
$selection.TypeParagraph()
$selection.TypeText("    * Impact: Next growth will add 9.5 TB causing 10-30 min blocking")
$selection.TypeParagraph()
$selection.TypeText("    * Action: Change to fixed growth (8 GB increments)")
$selection.TypeParagraph()
$selection.TypeParagraph()
$selection.Font.Name = "Consolas"
$selection.Font.Size = 10
$selection.TypeText("    ALTER DATABASE IntegrationHub MODIFY FILE")
$selection.TypeParagraph()
$selection.TypeText("    (NAME = N'IntegrationHub_log', FILEGROWTH = 8192MB);")
$selection.TypeParagraph()
$selection.Font.Name = "Calibri"
$selection.Font.Size = 11
$selection.TypeParagraph()

# Issue 4
$selection.Font.Bold = $true
$selection.TypeText("4. Saaed360-SQL-7 - 7 DATABASES WITH BACKUP ISSUES")
$selection.TypeParagraph()
$selection.Font.Bold = $false
$selection.TypeText("    * Critical: 4 databases never backed up (ASPState, Saaed360_Persistence, Saaed360_Tracking, SaaedSMSGateway)")
$selection.TypeParagraph()
$selection.TypeText("    * Warning: Criticalsaaed360dblive2 - Log backup >24h old")
$selection.TypeParagraph()
$selection.TypeText("    * Warning: 3 databases with full backup >7 days old")
$selection.TypeParagraph()
$selection.TypeText("    * Total Data at Risk: 37+ TB")
$selection.TypeParagraph()
$selection.TypeText("    * Action: Implement backup jobs immediately")
$selection.TypeParagraph()
$selection.TypeParagraph()

# Issue 5
$selection.Font.Bold = $true
$selection.TypeText("5. BACKUP & MAINTENANCE FAILURES ACROSS MULTIPLE SERVERS")
$selection.TypeParagraph()
$selection.Font.Bold = $false
$selection.TypeText("    * Saaed360-SQL-3: 3 failed jobs (job owner access issues)")
$selection.TypeParagraph()
$selection.TypeText("    * SAAEDEVGSQL3: Multiple maintenance jobs failing daily")
$selection.TypeParagraph()
$selection.TypeText("    * PR-VM-BI360-N1: 1 failed job")
$selection.TypeParagraph()
$selection.TypeText("    * Action: Fix job ownership and implement backup strategy")
$selection.TypeParagraph()
$selection.TypeParagraph()

# High Priority Warnings
$selection.Font.Size = 16
$selection.Font.Bold = $true
$selection.Font.Color = 0x0070C0  # Orange
$selection.TypeText("HIGH PRIORITY WARNINGS")
$selection.TypeParagraph()

$selection.Font.Size = 11
$selection.Font.Bold = $false
$selection.Font.Color = 0x000000

$selection.TypeText("    * Saaed360-SQL-7: Low disk space on F:\ (12.13% free)")
$selection.TypeParagraph()
$selection.TypeText("    * NO INDEX/STATISTICS MAINTENANCE: 6 of 8 servers have no maintenance plans")
$selection.TypeParagraph()
$selection.TypeText("      - Effect: Index fragmentation causes full table scans, slow queries, high CPU/IO")
$selection.TypeParagraph()
$selection.TypeText("      - Effect: Outdated statistics lead to poor query plans and performance issues")
$selection.TypeParagraph()
$selection.TypeText("      - Impact: Queries that should take seconds can take minutes or hours")
$selection.TypeParagraph()
$selection.TypeText("    * ImpoundYard-DB: xp_cmdshell enabled (security risk)")
$selection.TypeParagraph()
$selection.TypeText("    * ALL SERVERS: MAXDOP=0 (unlimited parallelism)")
$selection.TypeParagraph()
$selection.TypeText("    * 3 servers: IFI (Instant File Initialization) disabled")
$selection.TypeParagraph()
$selection.TypeParagraph()

# SQL Server Versions Section
$selection.Font.Size = 16
$selection.Font.Bold = $true
$selection.Font.Color = 0x0000FF  # Red
$selection.TypeText("SQL SERVER VERSIONS & SUPPORT STATUS")
$selection.TypeParagraph()

$selection.Font.Size = 11
$selection.Font.Bold = $false
$selection.Font.Color = 0x000000

$selection.Font.Bold = $true
$selection.TypeText("CRITICAL: SQL 2016 END OF SUPPORT - JULY 14, 2026 (6 MONTHS)")
$selection.TypeParagraph()
$selection.Font.Bold = $false
$selection.TypeText("    * 3 servers running SQL 2016 SP3 (PR-VM-BI360-N1, SAAEDEVGSQL3, SaaedEVGSQL4)")
$selection.TypeParagraph()
$selection.TypeText("    * After July 2026: No more security updates, compliance violations, unsupported")
$selection.TypeParagraph()
$selection.TypeText("    * Action: Plan upgrade to SQL 2022 or migrate to Azure SQL")
$selection.TypeParagraph()
$selection.TypeParagraph()

$selection.Font.Bold = $true
$selection.TypeText("CURRENT VERSION STATUS:")
$selection.TypeParagraph()
$selection.Font.Bold = $false

$table_versions = $selection.Tables.Add($selection.Range, 4, 4)
$table_versions.Style = "Grid Table 4 - Accent 1"
$table_versions.Cell(1,1).Range.Text = "SQL Version"
$table_versions.Cell(1,2).Range.Text = "Servers"
$table_versions.Cell(1,3).Range.Text = "Current Build"
$table_versions.Cell(1,4).Range.Text = "Latest CU"
$table_versions.Cell(2,1).Range.Text = "SQL 2016 SP3"
$table_versions.Cell(2,2).Range.Text = "3 servers"
$table_versions.Cell(2,3).Range.Text = "13.0.7029.3"
$table_versions.Cell(2,4).Range.Text = "END OF SUPPORT: Jul 2026"
$table_versions.Cell(3,1).Range.Text = "SQL 2019"
$table_versions.Cell(3,2).Range.Text = "2 servers"
$table_versions.Cell(3,3).Range.Text = "15.0.4382 / 15.0.4455"
$table_versions.Cell(3,4).Range.Text = "CU32 (15.0.4430.1)"
$table_versions.Cell(4,1).Range.Text = "SQL 2022"
$table_versions.Cell(4,2).Range.Text = "3 servers"
$table_versions.Cell(4,3).Range.Text = "16.0.4125 - 16.0.4175"
$table_versions.Cell(4,4).Range.Text = "CU22 (16.0.4225.2)"

$selection.EndOf(15) | Out-Null
$selection.MoveDown() | Out-Null
$selection.TypeParagraph()

$selection.TypeText("Note: CU updates require testing in version-specific test environments before production deployment.")
$selection.TypeParagraph()
$selection.TypeParagraph()

# Configuration Issues Table
$selection.Font.Size = 16
$selection.Font.Bold = $true
$selection.Font.Color = 0x0070C0
$selection.TypeText("CONFIGURATION ISSUES")
$selection.TypeParagraph()

$selection.Font.Size = 11
$selection.Font.Bold = $false
$selection.Font.Color = 0x000000

$table3 = $selection.Tables.Add($selection.Range, 5, 3)
$table3.Style = "Grid Table 4 - Accent 1"
$table3.Cell(1,1).Range.Text = "Issue"
$table3.Cell(1,2).Range.Text = "Current"
$table3.Cell(1,3).Range.Text = "Recommended"
$table3.Cell(2,1).Range.Text = "MAXDOP"
$table3.Cell(2,2).Range.Text = "0 (Unlimited)"
$table3.Cell(2,3).Range.Text = "8"
$table3.Cell(3,1).Range.Text = "Cost Threshold"
$table3.Cell(3,2).Range.Text = "5 (Default)"
$table3.Cell(3,3).Range.Text = "50"
$table3.Cell(4,1).Range.Text = "IFI Status"
$table3.Cell(4,2).Range.Text = "Disabled (3 servers)"
$table3.Cell(4,3).Range.Text = "Enable"
$table3.Cell(5,1).Range.Text = "TempDB Files"
$table3.Cell(5,2).Range.Text = "0 files (1 server)"
$table3.Cell(5,3).Range.Text = "Match CPU count"

$selection.EndOf(15) | Out-Null
$selection.MoveDown() | Out-Null
$selection.TypeParagraph()

# Page Break
$selection.InsertNewPage()

# Action Plan Section
$selection.Font.Size = 16
$selection.Font.Bold = $true
$selection.Font.Color = 0x00B050  # Green
$selection.TypeText("RECOMMENDED ACTION PLAN")
$selection.TypeParagraph()

$selection.Font.Size = 11
$selection.Font.Bold = $false
$selection.Font.Color = 0x000000

# Phase 1
$selection.Font.Size = 12
$selection.Font.Bold = $true
$selection.TypeText("PHASE 1: IMMEDIATE (Today/Tomorrow)")
$selection.TypeParagraph()
$selection.Font.Size = 11
$selection.Font.Bold = $false

$selection.TypeText("    [ ] Free up disk space on SaaedEVGSQL4 (E:\ drive)")
$selection.TypeParagraph()
$selection.TypeText("    [ ] Change log file growth from 10% to 8 GB fixed")
$selection.TypeParagraph()
$selection.TypeText("    [ ] Fix failed backup jobs (ownership issues)")
$selection.TypeParagraph()
$selection.TypeText("    [ ] Implement backup for Saaed360-SQL-7 (7 databases)")
$selection.TypeParagraph()
$selection.TypeParagraph()

# Phase 2
$selection.Font.Size = 12
$selection.Font.Bold = $true
$selection.TypeText("PHASE 2: THIS WEEK")
$selection.TypeParagraph()
$selection.Font.Size = 11
$selection.Font.Bold = $false

$selection.TypeText("    [ ] Enable IFI on 3 servers")
$selection.TypeParagraph()
$selection.TypeText("    [ ] Fix TempDB file configuration")
$selection.TypeParagraph()
$selection.TypeText("    [ ] Implement index maintenance jobs")
$selection.TypeParagraph()
$selection.TypeText("    [ ] Review and reduce SysAdmin accounts")
$selection.TypeParagraph()
$selection.TypeParagraph()

# Phase 3
$selection.Font.Size = 12
$selection.Font.Bold = $true
$selection.TypeText("PHASE 3: NEXT 2 WEEKS")
$selection.TypeParagraph()
$selection.Font.Size = 11
$selection.Font.Bold = $false

$selection.TypeText("    [ ] Adjust MAXDOP to 8 on all servers")
$selection.TypeParagraph()
$selection.TypeText("    [ ] Increase Cost Threshold for Parallelism to 50")
$selection.TypeParagraph()
$selection.TypeText("    [ ] Disable xp_cmdshell where not needed")
$selection.TypeParagraph()
$selection.TypeText("    [ ] Implement password policies for SQL logins")
$selection.TypeParagraph()
$selection.TypeParagraph()

# Phase 4
$selection.Font.Size = 12
$selection.Font.Bold = $true
$selection.TypeText("PHASE 4: SQL SERVER UPGRADES (PRIORITY)")
$selection.TypeParagraph()
$selection.Font.Size = 11
$selection.Font.Bold = $false

$selection.TypeText("    [ ] URGENT: Plan SQL 2016 upgrade (3 servers, 6 months until end of support)")
$selection.TypeParagraph()
$selection.TypeText("    [ ] Test SQL CU updates in version-specific test environments")
$selection.TypeParagraph()
$selection.TypeText("    [ ] Apply latest CUs to SQL 2019 servers (CU32)")
$selection.TypeParagraph()
$selection.TypeText("    [ ] Apply latest CUs to SQL 2022 servers (CU22)")
$selection.TypeParagraph()
$selection.TypeParagraph()

# Phase 5
$selection.Font.Size = 12
$selection.Font.Bold = $true
$selection.TypeText("PHASE 5: ONGOING MONITORING")
$selection.TypeParagraph()
$selection.Font.Size = 11
$selection.Font.Bold = $false

$selection.TypeText("    [ ] Set up disk space monitoring (alert at 20%)")
$selection.TypeParagraph()
$selection.TypeText("    [ ] Set up PLE monitoring (alert below 300)")
$selection.TypeParagraph()
$selection.TypeText("    [ ] Review backup strategy and retention")
$selection.TypeParagraph()
$selection.TypeText("    [ ] Schedule quarterly configuration reviews")
$selection.TypeParagraph()
$selection.TypeParagraph()

# Effort Table
$selection.Font.Size = 14
$selection.Font.Bold = $true
$selection.TypeText("ESTIMATED EFFORT & TIMELINE")
$selection.TypeParagraph()

$selection.Font.Size = 11
$selection.Font.Bold = $false

$table4 = $selection.Tables.Add($selection.Range, 6, 3)
$table4.Style = "Grid Table 4 - Accent 1"
$table4.Cell(1,1).Range.Text = "Phase"
$table4.Cell(1,2).Range.Text = "Timeline"
$table4.Cell(1,3).Range.Text = "Effort (Hours)"
$table4.Cell(2,1).Range.Text = "Phase 1 (Critical)"
$table4.Cell(2,2).Range.Text = "Today/Tomorrow"
$table4.Cell(2,3).Range.Text = "8-12 hours"
$table4.Cell(3,1).Range.Text = "Phase 2 (High Priority)"
$table4.Cell(3,2).Range.Text = "This Week"
$table4.Cell(3,3).Range.Text = "16-20 hours"
$table4.Cell(4,1).Range.Text = "Phase 3 (Configuration)"
$table4.Cell(4,2).Range.Text = "Next 2 Weeks"
$table4.Cell(4,3).Range.Text = "12-16 hours"
$table4.Cell(5,1).Range.Text = "Phase 4 (SQL Upgrades)"
$table4.Cell(5,2).Range.Text = "Next 6 months"
$table4.Cell(5,3).Range.Text = "Project-level effort"
$table4.Cell(6,1).Range.Text = "Phase 5 (Monitoring)"
$table4.Cell(6,2).Range.Text = "Ongoing"
$table4.Cell(6,3).Range.Text = "4-8 hours setup"

$selection.EndOf(15) | Out-Null
$selection.MoveDown() | Out-Null
$selection.TypeParagraph()

# Business Impact
$selection.Font.Size = 14
$selection.Font.Bold = $true
$selection.Font.Color = 0x0000FF
$selection.TypeText("BUSINESS IMPACT IF NOT ADDRESSED")
$selection.TypeParagraph()

$selection.Font.Size = 11
$selection.Font.Bold = $false
$selection.Font.Color = 0x000000

$selection.TypeText("    * Service Outage: SaaedEVGSQL4 within days (disk full)")
$selection.TypeParagraph()
$selection.TypeText("    * Data Loss Risk: Multiple servers without backups (45+ TB at risk)")
$selection.TypeParagraph()
$selection.TypeText("    * Performance Degradation: Affecting end users")
$selection.TypeParagraph()
$selection.TypeText("    * Compliance Risk: Potential audit failures")
$selection.TypeParagraph()

# Save document
$doc.SaveAs($wordPath)
$doc.Close()
$word.Quit()

[System.Runtime.Interopservices.Marshal]::ReleaseComObject($doc) | Out-Null
[System.Runtime.Interopservices.Marshal]::ReleaseComObject($word) | Out-Null
[System.GC]::Collect()
[System.GC]::WaitForPendingFinalizers()

Write-Host "Word document created successfully at: $wordPath" -ForegroundColor Green
