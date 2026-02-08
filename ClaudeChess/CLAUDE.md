# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

This is a **Microsoft Dynamics 365 Business Central** AL extension called **ClaudeChess**. It is built using the AL programming language and targets Business Central runtime 16.0 (application 27.0).

The purpose is to create a chess game in AL, running inside Business Central.

Create the following:
1. A controladdin for the UI chess board. It must be possible for the user to move pieces and for the computer to also move piece. There has to be an event triggered from the controladdin when the user wants to move a piece and then a procedure to accept the move and another to have the computer move and allow the user to move again.
2. A chess game engine, as a codeunit. The engine should be able to play at ELO 1000.
3. A host page for the control addin where the user can start games and resign.

## Build and Deploy

- **IDE**: VS Code with the AL Language extension (ms-dynamics-smb.al)
- **Build**: Use the AL Language extension command `AL: Package` (Ctrl+Shift+B) to compile the `.al` files into a `.app` package
- **Deploy/Publish**: Use `AL: Publish without debugging` (Ctrl+F5) or `AL: Publish` to deploy to the BC server
- **Debug**: F5 launches against the on-premise BC server configured in `.vscode/launch.json`

## Server Configuration

The app targets an **on-premise** Business Central instance:
- Server: `http://bc27` (instance: `BC`)
- Authentication: UserPassword
- Tenant: default
- Startup object: Page 53100

## Architecture

- **Object ID range**: 53100–53149 (assigned in `app.json`)
- **Dependencies**: Uses only the standard BC base symbols (System, System Application, Base Application, Business Foundation) — no third-party dependencies
- **Feature flags**: `NoImplicitWith` is enabled — all `with` blocks must be explicit

## AL Language Conventions

- All new objects must use IDs within the 53100–53149 range
- Use explicit `with` statements (implicit `with` is disabled via `NoImplicitWith` feature)
- Symbol packages are stored in `.alpackages/` and should not be edited manually
