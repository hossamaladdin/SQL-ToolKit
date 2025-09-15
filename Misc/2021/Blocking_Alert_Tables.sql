USE [master]
GO

/****** Object:  Table [dbo].[Monitor_Blocked]    Script Date: 30/11/2022 10:13:23 AM ******/
SET ANSI_NULLS ON
GO

SET QUOTED_IDENTIFIER ON
GO

CREATE TABLE [dbo].[Monitor_Blocked](
	[ID] [int] IDENTITY(1,1) NOT NULL,
	[WaitingSpid] [smallint] NULL,
	[BlockingSpid] [smallint] NULL,
	[LeadingBlocker] [smallint] NULL,
	[BlockingChain] [nvarchar](4000) NULL,
	[DbName] [sysname] NOT NULL,
	[HostName] [nvarchar](128) NULL,
	[ProgramName] [nvarchar](128) NULL,
	[LoginName] [nvarchar](128) NULL,
	[LoginTime] [datetime2](3) NULL,
	[LastRequestStart] [datetime2](3) NULL,
	[LastRequestEnd] [datetime2](3) NULL,
	[TransactionCnt] [int] NULL,
	[Command] [nvarchar](32) NULL,
	[WaitTime] [int] NULL,
	[WaitResource] [nvarchar](256) NULL,
	[WaitDescription] [nvarchar](1000) NULL,
	[SqlText] [nvarchar](max) NULL,
	[SqlStatement] [nvarchar](max) NULL,
	[InputBuffer] [nvarchar](4000) NULL,
	[SessionInfo] [nvarchar](max) NULL,
PRIMARY KEY CLUSTERED 
(
	[ID] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON, OPTIMIZE_FOR_SEQUENTIAL_KEY = OFF) ON [PRIMARY]
) ON [PRIMARY] TEXTIMAGE_ON [PRIMARY]
GO

/****** Object:  Table [dbo].[Monitor_Blocking]    Script Date: 30/11/2022 10:13:23 AM ******/
SET ANSI_NULLS ON
GO

SET QUOTED_IDENTIFIER ON
GO

CREATE TABLE [dbo].[Monitor_Blocking](
	[Id] [int] IDENTITY(1,1) NOT NULL,
	[LeadingBlocker] [smallint] NULL,
	[BlockedSpidCount] [int] NULL,
	[DbName] [sysname] NOT NULL,
	[HostName] [nvarchar](128) NULL,
	[ProgramName] [nvarchar](128) NULL,
	[LoginName] [nvarchar](128) NULL,
	[LoginTime] [datetime2](3) NULL,
	[LastRequestStart] [datetime2](3) NULL,
	[LastRequestEnd] [datetime2](3) NULL,
	[TransactionCnt] [int] NULL,
	[Command] [nvarchar](32) NULL,
	[WaitTime] [int] NULL,
	[WaitResource] [nvarchar](256) NULL,
	[WaitDescription] [nvarchar](1000) NULL,
	[SqlText] [nvarchar](max) NULL,
	[SqlStatement] [nvarchar](max) NULL,
	[InputBuffer] [nvarchar](4000) NULL,
	[SessionInfo] [nvarchar](max) NULL,
	[LogDateTime] [datetime2](7) NULL,
PRIMARY KEY CLUSTERED 
(
	[Id] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON, OPTIMIZE_FOR_SEQUENTIAL_KEY = OFF) ON [PRIMARY]
) ON [PRIMARY] TEXTIMAGE_ON [PRIMARY]
GO

ALTER TABLE [dbo].[Monitor_Blocking] ADD  DEFAULT (getdate()) FOR [LogDateTime]
GO

