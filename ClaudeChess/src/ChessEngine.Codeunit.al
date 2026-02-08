codeunit 53102 "Chess Engine"
{
    // Board representation: array[1..64] of Integer
    // Index 1 = a8 (top-left), Index 64 = h1 (bottom-right)
    // Row = (index - 1) div 8, Col = (index - 1) mod 8
    // Piece encoding: 1=Pawn, 2=Knight, 3=Bishop, 4=Rook, 5=Queen, 6=King
    // Positive = white, Negative = black, 0 = empty
    // Move encoding: FromSquare * 10000 + ToSquare * 10 + Flag
    // Flags: 0=normal, 1=en passant, 2=castling, 3=promo N, 4=promo B, 5=promo R, 6=promo Q

    var
        Board: array[64] of Integer;
        WhiteToMove: Boolean;
        WhiteCastleKing: Boolean;
        WhiteCastleQueen: Boolean;
        BlackCastleKing: Boolean;
        BlackCastleQueen: Boolean;
        EnPassantSq: Integer;  // 1-based, 0 = none
        HalfMoveClock: Integer;
        WhiteKingSq: Integer;  // 1-based
        BlackKingSq: Integer;  // 1-based
        GameState: Integer;    // 0=ongoing, 1=white wins, 2=black wins, 3=stalemate, 4=draw
        LastMoveEncoded: Integer;
        LastMoveNotation: Text;

        // Piece-square tables (midgame), indexed [piece 1..6, square 1..64] from white's perspective
        PawnPST: array[64] of Integer;
        KnightPST: array[64] of Integer;
        BishopPST: array[64] of Integer;
        RookPST: array[64] of Integer;
        QueenPST: array[64] of Integer;
        KingMidPST: array[64] of Integer;
        KingEndPST: array[64] of Integer;

        // Save/restore for search (depth up to 10)
        SavedBoard: array[10, 64] of Integer;
        SavedWhiteToMove: array[10] of Boolean;
        SavedWCK: array[10] of Boolean;
        SavedWCQ: array[10] of Boolean;
        SavedBCK: array[10] of Boolean;
        SavedBCQ: array[10] of Boolean;
        SavedEP: array[10] of Integer;
        SavedHMC: array[10] of Integer;
        SavedWKS: array[10] of Integer;
        SavedBKS: array[10] of Integer;

        PSTInitialized: Boolean;

    // ===== PUBLIC API =====

    procedure NewGame()
    begin
        InitPST();
        SetupStartPosition();
        GameState := 0;
        LastMoveEncoded := 0;
        LastMoveNotation := '';
    end;

    procedure GetBoardString(): Text
    var
        Result: Text;
        i: Integer;
        p: Integer;
    begin
        Result := '';
        for i := 1 to 64 do begin
            p := Board[i];
            case p of
                1:
                    Result += 'P';
                2:
                    Result += 'N';
                3:
                    Result += 'B';
                4:
                    Result += 'R';
                5:
                    Result += 'Q';
                6:
                    Result += 'K';
                -1:
                    Result += 'p';
                -2:
                    Result += 'n';
                -3:
                    Result += 'b';
                -4:
                    Result += 'r';
                -5:
                    Result += 'q';
                -6:
                    Result += 'k';
                else
                    Result += '.';
            end;
        end;
        exit(Result);
    end;

    procedure GetLegalMoves(FromSq0: Integer): Text
    var
        Moves: array[256] of Integer;
        MoveCount: Integer;
        FromSq: Integer;
        ToSq0: Integer;
        m: Integer;
        i: Integer;
        ResultText: Text;
        Seen: array[64] of Boolean;
    begin
        // FromSq0 is 0-based, convert to 1-based
        FromSq := FromSq0 + 1;
        GenerateLegalMoves(Moves, MoveCount);
        ResultText := '';
        for i := 1 to MoveCount do begin
            m := Moves[i];
            if GetFrom(m) = FromSq then begin
                ToSq0 := GetTo(m) - 1;  // Convert to 0-based
                if not Seen[ToSq0 + 1] then begin
                    Seen[ToSq0 + 1] := true;
                    if ResultText <> '' then
                        ResultText += ',';
                    ResultText += Format(ToSq0);
                end;
            end;
        end;
        exit(ResultText);
    end;

    procedure ApplyPlayerMove(FromSq0: Integer; ToSq0: Integer; PromotionPiece: Integer): Boolean
    var
        Moves: array[256] of Integer;
        MoveCount: Integer;
        FromSq: Integer;
        ToSq: Integer;
        m: Integer;
        i: Integer;
        flag: Integer;
        ExpectedFlag: Integer;
        IsMatch: Boolean;
    begin
        FromSq := FromSq0 + 1;
        ToSq := ToSq0 + 1;
        GenerateLegalMoves(Moves, MoveCount);
        for i := 1 to MoveCount do begin
            m := Moves[i];
            if (GetFrom(m) = FromSq) and (GetTo(m) = ToSq) then begin
                flag := GetFlag(m);
                IsMatch := true;
                // Match promotion piece if applicable
                if flag >= 3 then begin
                    // Map PromotionPiece (2=N,3=B,4=R,5=Q) to flag (3=N,4=B,5=R,6=Q)
                    case PromotionPiece of
                        2:
                            ExpectedFlag := 3;
                        3:
                            ExpectedFlag := 4;
                        4:
                            ExpectedFlag := 5;
                        else
                            ExpectedFlag := 6;  // Default to queen
                    end;
                    IsMatch := (flag = ExpectedFlag);
                end;
                if IsMatch then begin
                    LastMoveNotation := ComputeMoveNotation(m);
                    MakeMove(m);
                    LastMoveEncoded := m;
                    UpdateGameState();
                    AppendCheckSuffix();
                    exit(true);
                end;
            end;
        end;
        exit(false);
    end;

    procedure ComputeEngineMove(): Integer
    var
        BestMove: Integer;
    begin
        BestMove := FindBestMove();
        if BestMove <> 0 then begin
            LastMoveNotation := ComputeMoveNotation(BestMove);
            MakeMove(BestMove);
            LastMoveEncoded := BestMove;
            UpdateGameState();
            AppendCheckSuffix();
        end;
        exit(BestMove);
    end;

    procedure GetMoveFrom(EncodedMove: Integer): Integer
    begin
        // Return 0-based
        exit(GetFrom(EncodedMove) - 1);
    end;

    procedure GetMoveTo(EncodedMove: Integer): Integer
    begin
        // Return 0-based
        exit(GetTo(EncodedMove) - 1);
    end;

    procedure GetMovePromotion(EncodedMove: Integer): Text
    var
        flag: Integer;
    begin
        flag := GetFlag(EncodedMove);
        case flag of
            3:
                exit('N');
            4:
                exit('B');
            5:
                exit('R');
            6:
                exit('Q');
            else
                exit('');
        end;
    end;

    procedure GetGameState(): Integer
    begin
        exit(GameState);
    end;

    procedure IsWhiteToMove(): Boolean
    begin
        exit(WhiteToMove);
    end;

    procedure IsCurrentSideInCheck(): Boolean
    begin
        if WhiteToMove then
            exit(IsSquareAttacked(WhiteKingSq, false))
        else
            exit(IsSquareAttacked(BlackKingSq, true));
    end;

    procedure GetKingSquare0(IsWhite: Boolean): Integer
    begin
        if IsWhite then
            exit(WhiteKingSq - 1)
        else
            exit(BlackKingSq - 1);
    end;

    procedure GetLastMoveNotation(): Text
    begin
        exit(LastMoveNotation);
    end;

    procedure GetCapturedPieces(ByWhite: Boolean): Text
    var
        PawnCnt: Integer;
        KnightCnt: Integer;
        BishopCnt: Integer;
        RookCnt: Integer;
        QueenCnt: Integer;
        Missing: Integer;
        i: Integer;
        j: Integer;
        Result: Text;
    begin
        // Count opponent pieces remaining on board
        for i := 1 to 64 do
            if ByWhite then begin
                case Board[i] of
                    -1:
                        PawnCnt += 1;
                    -2:
                        KnightCnt += 1;
                    -3:
                        BishopCnt += 1;
                    -4:
                        RookCnt += 1;
                    -5:
                        QueenCnt += 1;
                end;
            end else begin
                case Board[i] of
                    1:
                        PawnCnt += 1;
                    2:
                        KnightCnt += 1;
                    3:
                        BishopCnt += 1;
                    4:
                        RookCnt += 1;
                    5:
                        QueenCnt += 1;
                end;
            end;

        Result := '';

        // Show captured pieces in value order: Q, R, B, N, P
        // ByWhite=true → show black piece symbols (captured by white)
        // ByWhite=false → show white piece symbols (captured by black)
        Missing := 1 - QueenCnt;
        if Missing > 0 then
            for j := 1 to Missing do
                if ByWhite then
                    Result += '♛'
                else
                    Result += '♕';

        Missing := 2 - RookCnt;
        if Missing > 0 then
            for j := 1 to Missing do
                if ByWhite then
                    Result += '♜'
                else
                    Result += '♖';

        Missing := 2 - BishopCnt;
        if Missing > 0 then
            for j := 1 to Missing do
                if ByWhite then
                    Result += '♝'
                else
                    Result += '♗';

        Missing := 2 - KnightCnt;
        if Missing > 0 then
            for j := 1 to Missing do
                if ByWhite then
                    Result += '♞'
                else
                    Result += '♘';

        Missing := 8 - PawnCnt;
        if Missing > 0 then
            for j := 1 to Missing do
                if ByWhite then
                    Result += '♟'
                else
                    Result += '♙';

        exit(Result);
    end;

    procedure GetMaterialBalance(): Integer
    var
        i: Integer;
        Balance: Integer;
    begin
        Balance := 0;
        for i := 1 to 64 do
            case Board[i] of
                1:
                    Balance += 100;
                2:
                    Balance += 320;
                3:
                    Balance += 330;
                4:
                    Balance += 500;
                5:
                    Balance += 900;
                -1:
                    Balance -= 100;
                -2:
                    Balance -= 320;
                -3:
                    Balance -= 330;
                -4:
                    Balance -= 500;
                -5:
                    Balance -= 900;
            end;
        exit(Balance);
    end;

    // ===== SETUP =====

    local procedure SetupStartPosition()
    var
        i: Integer;
    begin
        // Clear board
        for i := 1 to 64 do
            Board[i] := 0;

        // Black pieces (row 0 = indices 1-8)
        Board[1] := -4;  // a8 = black rook
        Board[2] := -2;  // b8 = black knight
        Board[3] := -3;  // c8 = black bishop
        Board[4] := -5;  // d8 = black queen
        Board[5] := -6;  // e8 = black king
        Board[6] := -3;  // f8 = black bishop
        Board[7] := -2;  // g8 = black knight
        Board[8] := -4;  // h8 = black rook

        // Black pawns (row 1 = indices 9-16)
        for i := 9 to 16 do
            Board[i] := -1;

        // White pawns (row 6 = indices 49-56)
        for i := 49 to 56 do
            Board[i] := 1;

        // White pieces (row 7 = indices 57-64)
        Board[57] := 4;  // a1 = white rook
        Board[58] := 2;  // b1 = white knight
        Board[59] := 3;  // c1 = white bishop
        Board[60] := 5;  // d1 = white queen
        Board[61] := 6;  // e1 = white king
        Board[62] := 3;  // f1 = white bishop
        Board[63] := 2;  // g1 = white knight
        Board[64] := 4;  // h1 = white rook

        WhiteToMove := true;
        WhiteCastleKing := true;
        WhiteCastleQueen := true;
        BlackCastleKing := true;
        BlackCastleQueen := true;
        EnPassantSq := 0;
        HalfMoveClock := 0;
        WhiteKingSq := 61;
        BlackKingSq := 5;
    end;

    // ===== MOVE ENCODING =====

    local procedure EncodeMove(FromSq: Integer; ToSq: Integer; Flag: Integer): Integer
    begin
        exit(FromSq * 10000 + ToSq * 10 + Flag);
    end;

    local procedure GetFrom(Move: Integer): Integer
    begin
        exit(Move div 10000);
    end;

    local procedure GetTo(Move: Integer): Integer
    begin
        exit((Move mod 10000) div 10);
    end;

    local procedure GetFlag(Move: Integer): Integer
    begin
        exit(Move mod 10);
    end;

    // ===== BOARD HELPERS =====

    local procedure GetRow(Sq: Integer): Integer
    begin
        exit((Sq - 1) div 8);
    end;

    local procedure GetCol(Sq: Integer): Integer
    begin
        exit((Sq - 1) mod 8);
    end;

    local procedure SquareFromRC(Row: Integer; Col: Integer): Integer
    begin
        exit(Row * 8 + Col + 1);
    end;

    local procedure IsFriendly(Piece: Integer; SideIsWhite: Boolean): Boolean
    begin
        if SideIsWhite then
            exit(Piece > 0)
        else
            exit(Piece < 0);
    end;

    local procedure IsEnemy(Piece: Integer; SideIsWhite: Boolean): Boolean
    begin
        if SideIsWhite then
            exit(Piece < 0)
        else
            exit(Piece > 0);
    end;

    local procedure AbsPiece(Piece: Integer): Integer
    begin
        if Piece < 0 then
            exit(-Piece);
        exit(Piece);
    end;

    // ===== ATTACK DETECTION =====

    local procedure IsSquareAttacked(Sq: Integer; ByWhite: Boolean): Boolean
    var
        Row: Integer;
        Col: Integer;
        r: Integer;
        c: Integer;
        Piece: Integer;
        dr: Integer;
        dc: Integer;
        dist: Integer;
        KnightDR: array[8] of Integer;
        KnightDC: array[8] of Integer;
        i: Integer;
    begin
        Row := GetRow(Sq);
        Col := GetCol(Sq);

        // Check pawn attacks
        if ByWhite then begin
            // White pawns attack from below (higher row)
            if (Row + 1 <= 7) then begin
                if (Col - 1 >= 0) and (Board[SquareFromRC(Row + 1, Col - 1)] = 1) then
                    exit(true);
                if (Col + 1 <= 7) and (Board[SquareFromRC(Row + 1, Col + 1)] = 1) then
                    exit(true);
            end;
        end else begin
            // Black pawns attack from above (lower row)
            if (Row - 1 >= 0) then begin
                if (Col - 1 >= 0) and (Board[SquareFromRC(Row - 1, Col - 1)] = -1) then
                    exit(true);
                if (Col + 1 <= 7) and (Board[SquareFromRC(Row - 1, Col + 1)] = -1) then
                    exit(true);
            end;
        end;

        // Check knight attacks
        KnightDR[1] := -2; KnightDC[1] := -1;
        KnightDR[2] := -2; KnightDC[2] := 1;
        KnightDR[3] := -1; KnightDC[3] := -2;
        KnightDR[4] := -1; KnightDC[4] := 2;
        KnightDR[5] := 1; KnightDC[5] := -2;
        KnightDR[6] := 1; KnightDC[6] := 2;
        KnightDR[7] := 2; KnightDC[7] := -1;
        KnightDR[8] := 2; KnightDC[8] := 1;

        for i := 1 to 8 do begin
            r := Row + KnightDR[i];
            c := Col + KnightDC[i];
            if (r >= 0) and (r <= 7) and (c >= 0) and (c <= 7) then begin
                Piece := Board[SquareFromRC(r, c)];
                if ByWhite and (Piece = 2) then
                    exit(true);
                if (not ByWhite) and (Piece = -2) then
                    exit(true);
            end;
        end;

        // Check king attacks
        for dr := -1 to 1 do
            for dc := -1 to 1 do begin
                if (dr = 0) and (dc = 0) then
                    continue;
                r := Row + dr;
                c := Col + dc;
                if (r >= 0) and (r <= 7) and (c >= 0) and (c <= 7) then begin
                    Piece := Board[SquareFromRC(r, c)];
                    if ByWhite and (Piece = 6) then
                        exit(true);
                    if (not ByWhite) and (Piece = -6) then
                        exit(true);
                end;
            end;

        // Check sliding pieces (bishop/queen diagonals, rook/queen straights)
        // Diagonal directions
        for i := 1 to 4 do begin
            case i of
                1:
                    begin
                        dr := -1; dc := -1;
                    end;
                2:
                    begin
                        dr := -1; dc := 1;
                    end;
                3:
                    begin
                        dr := 1; dc := -1;
                    end;
                4:
                    begin
                        dr := 1; dc := 1;
                    end;
            end;
            for dist := 1 to 7 do begin
                r := Row + dr * dist;
                c := Col + dc * dist;
                if (r < 0) or (r > 7) or (c < 0) or (c > 7) then
                    break;
                Piece := Board[SquareFromRC(r, c)];
                if Piece <> 0 then begin
                    if ByWhite and ((Piece = 3) or (Piece = 5)) then
                        exit(true);
                    if (not ByWhite) and ((Piece = -3) or (Piece = -5)) then
                        exit(true);
                    break;  // Piece blocks further sliding
                end;
            end;
        end;

        // Straight directions
        for i := 1 to 4 do begin
            case i of
                1:
                    begin
                        dr := -1; dc := 0;
                    end;
                2:
                    begin
                        dr := 1; dc := 0;
                    end;
                3:
                    begin
                        dr := 0; dc := -1;
                    end;
                4:
                    begin
                        dr := 0; dc := 1;
                    end;
            end;
            for dist := 1 to 7 do begin
                r := Row + dr * dist;
                c := Col + dc * dist;
                if (r < 0) or (r > 7) or (c < 0) or (c > 7) then
                    break;
                Piece := Board[SquareFromRC(r, c)];
                if Piece <> 0 then begin
                    if ByWhite and ((Piece = 4) or (Piece = 5)) then
                        exit(true);
                    if (not ByWhite) and ((Piece = -4) or (Piece = -5)) then
                        exit(true);
                    break;
                end;
            end;
        end;

        exit(false);
    end;

    // ===== MOVE GENERATION =====

    local procedure GeneratePseudoLegalMoves(var Moves: array[256] of Integer; var MoveCount: Integer)
    var
        i: Integer;
        Piece: Integer;
        SideIsWhite: Boolean;
    begin
        MoveCount := 0;
        SideIsWhite := WhiteToMove;

        for i := 1 to 64 do begin
            Piece := Board[i];
            if Piece = 0 then
                continue;
            if SideIsWhite and (Piece < 0) then
                continue;
            if (not SideIsWhite) and (Piece > 0) then
                continue;

            case AbsPiece(Piece) of
                1:
                    GeneratePawnMoves(i, SideIsWhite, Moves, MoveCount);
                2:
                    GenerateKnightMoves(i, SideIsWhite, Moves, MoveCount);
                3:
                    GenerateBishopMoves(i, SideIsWhite, Moves, MoveCount);
                4:
                    GenerateRookMoves(i, SideIsWhite, Moves, MoveCount);
                5:
                    GenerateQueenMoves(i, SideIsWhite, Moves, MoveCount);
                6:
                    GenerateKingMoves(i, SideIsWhite, Moves, MoveCount);
            end;
        end;
    end;

    local procedure AddMove(var Moves: array[256] of Integer; var MoveCount: Integer; Move: Integer)
    begin
        if MoveCount < 256 then begin
            MoveCount += 1;
            Moves[MoveCount] := Move;
        end;
    end;

    local procedure GeneratePawnMoves(Sq: Integer; SideIsWhite: Boolean; var Moves: array[256] of Integer; var MoveCount: Integer)
    var
        Row: Integer;
        Col: Integer;
        Dir: Integer;
        StartRow: Integer;
        PromoRow: Integer;
        TargetSq: Integer;
        CapSq: Integer;
    begin
        Row := GetRow(Sq);
        Col := GetCol(Sq);

        if SideIsWhite then begin
            Dir := -1;     // White moves up (decreasing row)
            StartRow := 6;
            PromoRow := 0;
        end else begin
            Dir := 1;      // Black moves down (increasing row)
            StartRow := 1;
            PromoRow := 7;
        end;

        // Forward one
        if (Row + Dir >= 0) and (Row + Dir <= 7) then begin
            TargetSq := SquareFromRC(Row + Dir, Col);
            if Board[TargetSq] = 0 then begin
                if (Row + Dir) = PromoRow then begin
                    AddMove(Moves, MoveCount, EncodeMove(Sq, TargetSq, 3));  // N
                    AddMove(Moves, MoveCount, EncodeMove(Sq, TargetSq, 4));  // B
                    AddMove(Moves, MoveCount, EncodeMove(Sq, TargetSq, 5));  // R
                    AddMove(Moves, MoveCount, EncodeMove(Sq, TargetSq, 6));  // Q
                end else begin
                    AddMove(Moves, MoveCount, EncodeMove(Sq, TargetSq, 0));
                    // Forward two from start
                    if Row = StartRow then begin
                        TargetSq := SquareFromRC(Row + 2 * Dir, Col);
                        if Board[TargetSq] = 0 then
                            AddMove(Moves, MoveCount, EncodeMove(Sq, TargetSq, 0));
                    end;
                end;
            end;
        end;

        // Captures (including en passant)
        if (Row + Dir >= 0) and (Row + Dir <= 7) then begin
            // Left capture
            if Col - 1 >= 0 then begin
                CapSq := SquareFromRC(Row + Dir, Col - 1);
                if IsEnemy(Board[CapSq], SideIsWhite) then begin
                    if (Row + Dir) = PromoRow then begin
                        AddMove(Moves, MoveCount, EncodeMove(Sq, CapSq, 3));
                        AddMove(Moves, MoveCount, EncodeMove(Sq, CapSq, 4));
                        AddMove(Moves, MoveCount, EncodeMove(Sq, CapSq, 5));
                        AddMove(Moves, MoveCount, EncodeMove(Sq, CapSq, 6));
                    end else
                        AddMove(Moves, MoveCount, EncodeMove(Sq, CapSq, 0));
                end else if CapSq = EnPassantSq then
                    AddMove(Moves, MoveCount, EncodeMove(Sq, CapSq, 1));
            end;
            // Right capture
            if Col + 1 <= 7 then begin
                CapSq := SquareFromRC(Row + Dir, Col + 1);
                if IsEnemy(Board[CapSq], SideIsWhite) then begin
                    if (Row + Dir) = PromoRow then begin
                        AddMove(Moves, MoveCount, EncodeMove(Sq, CapSq, 3));
                        AddMove(Moves, MoveCount, EncodeMove(Sq, CapSq, 4));
                        AddMove(Moves, MoveCount, EncodeMove(Sq, CapSq, 5));
                        AddMove(Moves, MoveCount, EncodeMove(Sq, CapSq, 6));
                    end else
                        AddMove(Moves, MoveCount, EncodeMove(Sq, CapSq, 0));
                end else if CapSq = EnPassantSq then
                    AddMove(Moves, MoveCount, EncodeMove(Sq, CapSq, 1));
            end;
        end;
    end;

    local procedure GenerateKnightMoves(Sq: Integer; SideIsWhite: Boolean; var Moves: array[256] of Integer; var MoveCount: Integer)
    var
        Row: Integer;
        Col: Integer;
        r: Integer;
        c: Integer;
        TargetSq: Integer;
        KnightDR: array[8] of Integer;
        KnightDC: array[8] of Integer;
        i: Integer;
    begin
        Row := GetRow(Sq);
        Col := GetCol(Sq);

        KnightDR[1] := -2; KnightDC[1] := -1;
        KnightDR[2] := -2; KnightDC[2] := 1;
        KnightDR[3] := -1; KnightDC[3] := -2;
        KnightDR[4] := -1; KnightDC[4] := 2;
        KnightDR[5] := 1; KnightDC[5] := -2;
        KnightDR[6] := 1; KnightDC[6] := 2;
        KnightDR[7] := 2; KnightDC[7] := -1;
        KnightDR[8] := 2; KnightDC[8] := 1;

        for i := 1 to 8 do begin
            r := Row + KnightDR[i];
            c := Col + KnightDC[i];
            if (r >= 0) and (r <= 7) and (c >= 0) and (c <= 7) then begin
                TargetSq := SquareFromRC(r, c);
                if not IsFriendly(Board[TargetSq], SideIsWhite) then
                    AddMove(Moves, MoveCount, EncodeMove(Sq, TargetSq, 0));
            end;
        end;
    end;

    local procedure GenerateSlidingMoves(Sq: Integer; SideIsWhite: Boolean; DirRow: Integer; DirCol: Integer; var Moves: array[256] of Integer; var MoveCount: Integer)
    var
        Row: Integer;
        Col: Integer;
        r: Integer;
        c: Integer;
        TargetSq: Integer;
        dist: Integer;
    begin
        Row := GetRow(Sq);
        Col := GetCol(Sq);

        for dist := 1 to 7 do begin
            r := Row + DirRow * dist;
            c := Col + DirCol * dist;
            if (r < 0) or (r > 7) or (c < 0) or (c > 7) then
                break;
            TargetSq := SquareFromRC(r, c);
            if IsFriendly(Board[TargetSq], SideIsWhite) then
                break;
            AddMove(Moves, MoveCount, EncodeMove(Sq, TargetSq, 0));
            if IsEnemy(Board[TargetSq], SideIsWhite) then
                break;
        end;
    end;

    local procedure GenerateBishopMoves(Sq: Integer; SideIsWhite: Boolean; var Moves: array[256] of Integer; var MoveCount: Integer)
    begin
        GenerateSlidingMoves(Sq, SideIsWhite, -1, -1, Moves, MoveCount);
        GenerateSlidingMoves(Sq, SideIsWhite, -1, 1, Moves, MoveCount);
        GenerateSlidingMoves(Sq, SideIsWhite, 1, -1, Moves, MoveCount);
        GenerateSlidingMoves(Sq, SideIsWhite, 1, 1, Moves, MoveCount);
    end;

    local procedure GenerateRookMoves(Sq: Integer; SideIsWhite: Boolean; var Moves: array[256] of Integer; var MoveCount: Integer)
    begin
        GenerateSlidingMoves(Sq, SideIsWhite, -1, 0, Moves, MoveCount);
        GenerateSlidingMoves(Sq, SideIsWhite, 1, 0, Moves, MoveCount);
        GenerateSlidingMoves(Sq, SideIsWhite, 0, -1, Moves, MoveCount);
        GenerateSlidingMoves(Sq, SideIsWhite, 0, 1, Moves, MoveCount);
    end;

    local procedure GenerateQueenMoves(Sq: Integer; SideIsWhite: Boolean; var Moves: array[256] of Integer; var MoveCount: Integer)
    begin
        GenerateBishopMoves(Sq, SideIsWhite, Moves, MoveCount);
        GenerateRookMoves(Sq, SideIsWhite, Moves, MoveCount);
    end;

    local procedure GenerateKingMoves(Sq: Integer; SideIsWhite: Boolean; var Moves: array[256] of Integer; var MoveCount: Integer)
    var
        Row: Integer;
        Col: Integer;
        r: Integer;
        c: Integer;
        TargetSq: Integer;
        dr: Integer;
        dc: Integer;
    begin
        Row := GetRow(Sq);
        Col := GetCol(Sq);

        for dr := -1 to 1 do
            for dc := -1 to 1 do begin
                if (dr = 0) and (dc = 0) then
                    continue;
                r := Row + dr;
                c := Col + dc;
                if (r >= 0) and (r <= 7) and (c >= 0) and (c <= 7) then begin
                    TargetSq := SquareFromRC(r, c);
                    if not IsFriendly(Board[TargetSq], SideIsWhite) then
                        AddMove(Moves, MoveCount, EncodeMove(Sq, TargetSq, 0));
                end;
            end;

        // Castling
        if SideIsWhite then begin
            // White king side: e1(61) -> g1(63), rook h1(64) -> f1(62)
            if WhiteCastleKing and (Sq = 61) and (Board[62] = 0) and (Board[63] = 0) and (Board[64] = 4) then
                if (not IsSquareAttacked(61, false)) and (not IsSquareAttacked(62, false)) and (not IsSquareAttacked(63, false)) then
                    AddMove(Moves, MoveCount, EncodeMove(61, 63, 2));

            // White queen side: e1(61) -> c1(59), rook a1(57) -> d1(60)
            if WhiteCastleQueen and (Sq = 61) and (Board[60] = 0) and (Board[59] = 0) and (Board[58] = 0) and (Board[57] = 4) then
                if (not IsSquareAttacked(61, false)) and (not IsSquareAttacked(60, false)) and (not IsSquareAttacked(59, false)) then
                    AddMove(Moves, MoveCount, EncodeMove(61, 59, 2));
        end else begin
            // Black king side: e8(5) -> g8(7), rook h8(8) -> f8(6)
            if BlackCastleKing and (Sq = 5) and (Board[6] = 0) and (Board[7] = 0) and (Board[8] = -4) then
                if (not IsSquareAttacked(5, true)) and (not IsSquareAttacked(6, true)) and (not IsSquareAttacked(7, true)) then
                    AddMove(Moves, MoveCount, EncodeMove(5, 7, 2));

            // Black queen side: e8(5) -> c8(3), rook a8(1) -> d8(4)
            if BlackCastleQueen and (Sq = 5) and (Board[4] = 0) and (Board[3] = 0) and (Board[2] = 0) and (Board[1] = -4) then
                if (not IsSquareAttacked(5, true)) and (not IsSquareAttacked(4, true)) and (not IsSquareAttacked(3, true)) then
                    AddMove(Moves, MoveCount, EncodeMove(5, 3, 2));
        end;
    end;

    local procedure GenerateLegalMoves(var Moves: array[256] of Integer; var MoveCount: Integer)
    var
        PseudoMoves: array[256] of Integer;
        PseudoCount: Integer;
        i: Integer;
        m: Integer;
        KingSq: Integer;
    begin
        GeneratePseudoLegalMoves(PseudoMoves, PseudoCount);
        MoveCount := 0;

        for i := 1 to PseudoCount do begin
            m := PseudoMoves[i];
            SaveState(1);
            MakeMove(m);
            // After MakeMove, side has changed. Check if the side that just moved left its king in check.
            // The side that moved was the opposite of current WhiteToMove.
            if WhiteToMove then
                // Black just moved - check if black king is attacked by white
                KingSq := BlackKingSq
            else
                // White just moved - check if white king is attacked by black
                KingSq := WhiteKingSq;

            if not IsSquareAttacked(KingSq, WhiteToMove) then begin
                MoveCount += 1;
                Moves[MoveCount] := m;
            end;
            RestoreState(1);
        end;
    end;

    // ===== MAKE/UNMAKE MOVE =====

    local procedure MakeMove(Move: Integer)
    var
        FromSq: Integer;
        ToSq: Integer;
        Flag: Integer;
        Piece: Integer;
        CapturedPawnSq: Integer;
        PromoPiece: Integer;
        MovingRow: Integer;
        ToRow: Integer;
        ToCol: Integer;
        FromCol: Integer;
    begin
        FromSq := GetFrom(Move);
        ToSq := GetTo(Move);
        Flag := GetFlag(Move);
        Piece := Board[FromSq];

        HalfMoveClock += 1;

        // Reset half-move clock on pawn move or capture
        if (AbsPiece(Piece) = 1) or (Board[ToSq] <> 0) then
            HalfMoveClock := 0;

        // Handle en passant capture
        if Flag = 1 then begin
            // Remove the captured pawn
            if Piece > 0 then
                // White captures en passant: captured pawn is one row below target
                CapturedPawnSq := ToSq + 8
            else
                // Black captures en passant: captured pawn is one row above target
                CapturedPawnSq := ToSq - 8;
            Board[CapturedPawnSq] := 0;
        end;

        // Handle castling
        if Flag = 2 then begin
            if (FromSq = 61) and (ToSq = 63) then begin
                // White king side
                Board[64] := 0;
                Board[62] := 4;
            end else if (FromSq = 61) and (ToSq = 59) then begin
                // White queen side
                Board[57] := 0;
                Board[60] := 4;
            end else if (FromSq = 5) and (ToSq = 7) then begin
                // Black king side
                Board[8] := 0;
                Board[6] := -4;
            end else if (FromSq = 5) and (ToSq = 3) then begin
                // Black queen side
                Board[1] := 0;
                Board[4] := -4;
            end;
        end;

        // Move the piece
        Board[ToSq] := Piece;
        Board[FromSq] := 0;

        // Handle promotion
        if Flag >= 3 then begin
            case Flag of
                3:
                    PromoPiece := 2;  // Knight
                4:
                    PromoPiece := 3;  // Bishop
                5:
                    PromoPiece := 4;  // Rook
                6:
                    PromoPiece := 5;  // Queen
            end;
            if Piece < 0 then
                PromoPiece := -PromoPiece;
            Board[ToSq] := PromoPiece;
        end;

        // Update en passant square
        EnPassantSq := 0;
        if AbsPiece(Piece) = 1 then begin
            MovingRow := GetRow(FromSq);
            ToRow := GetRow(ToSq);
            if Abs(MovingRow - ToRow) = 2 then begin
                // Double pawn push - set EP square
                if Piece > 0 then
                    EnPassantSq := FromSq - 8   // Square behind white pawn
                else
                    EnPassantSq := FromSq + 8;  // Square behind black pawn
            end;
        end;

        // Update castling rights
        if FromSq = 61 then begin  // White king moved
            WhiteCastleKing := false;
            WhiteCastleQueen := false;
        end;
        if FromSq = 5 then begin   // Black king moved
            BlackCastleKing := false;
            BlackCastleQueen := false;
        end;
        if (FromSq = 64) or (ToSq = 64) then  // h1 rook
            WhiteCastleKing := false;
        if (FromSq = 57) or (ToSq = 57) then  // a1 rook
            WhiteCastleQueen := false;
        if (FromSq = 8) or (ToSq = 8) then    // h8 rook
            BlackCastleKing := false;
        if (FromSq = 1) or (ToSq = 1) then    // a8 rook
            BlackCastleQueen := false;

        // Update king square tracking
        if AbsPiece(Piece) = 6 then begin
            if Piece > 0 then
                WhiteKingSq := ToSq
            else
                BlackKingSq := ToSq;
        end;

        // Switch side
        WhiteToMove := not WhiteToMove;
    end;

    local procedure SaveState(Depth: Integer)
    var
        i: Integer;
    begin
        for i := 1 to 64 do
            SavedBoard[Depth, i] := Board[i];
        SavedWhiteToMove[Depth] := WhiteToMove;
        SavedWCK[Depth] := WhiteCastleKing;
        SavedWCQ[Depth] := WhiteCastleQueen;
        SavedBCK[Depth] := BlackCastleKing;
        SavedBCQ[Depth] := BlackCastleQueen;
        SavedEP[Depth] := EnPassantSq;
        SavedHMC[Depth] := HalfMoveClock;
        SavedWKS[Depth] := WhiteKingSq;
        SavedBKS[Depth] := BlackKingSq;
    end;

    local procedure RestoreState(Depth: Integer)
    var
        i: Integer;
    begin
        for i := 1 to 64 do
            Board[i] := SavedBoard[Depth, i];
        WhiteToMove := SavedWhiteToMove[Depth];
        WhiteCastleKing := SavedWCK[Depth];
        WhiteCastleQueen := SavedWCQ[Depth];
        BlackCastleKing := SavedBCK[Depth];
        BlackCastleQueen := SavedBCQ[Depth];
        EnPassantSq := SavedEP[Depth];
        HalfMoveClock := SavedHMC[Depth];
        WhiteKingSq := SavedWKS[Depth];
        BlackKingSq := SavedBKS[Depth];
    end;

    // ===== EVALUATION =====

    local procedure InitPST()
    begin
        if PSTInitialized then
            exit;
        PSTInitialized := true;

        // Pawn PST (from white's perspective, index 1=a8 .. 64=h1)
        PawnPST[1] := 0; PawnPST[2] := 0; PawnPST[3] := 0; PawnPST[4] := 0; PawnPST[5] := 0; PawnPST[6] := 0; PawnPST[7] := 0; PawnPST[8] := 0;
        PawnPST[9] := 50; PawnPST[10] := 50; PawnPST[11] := 50; PawnPST[12] := 50; PawnPST[13] := 50; PawnPST[14] := 50; PawnPST[15] := 50; PawnPST[16] := 50;
        PawnPST[17] := 10; PawnPST[18] := 10; PawnPST[19] := 20; PawnPST[20] := 30; PawnPST[21] := 30; PawnPST[22] := 20; PawnPST[23] := 10; PawnPST[24] := 10;
        PawnPST[25] := 5; PawnPST[26] := 5; PawnPST[27] := 10; PawnPST[28] := 25; PawnPST[29] := 25; PawnPST[30] := 10; PawnPST[31] := 5; PawnPST[32] := 5;
        PawnPST[33] := 0; PawnPST[34] := 0; PawnPST[35] := 0; PawnPST[36] := 20; PawnPST[37] := 20; PawnPST[38] := 0; PawnPST[39] := 0; PawnPST[40] := 0;
        PawnPST[41] := 5; PawnPST[42] := -5; PawnPST[43] := -10; PawnPST[44] := 0; PawnPST[45] := 0; PawnPST[46] := -10; PawnPST[47] := -5; PawnPST[48] := 5;
        PawnPST[49] := 5; PawnPST[50] := 10; PawnPST[51] := 10; PawnPST[52] := -20; PawnPST[53] := -20; PawnPST[54] := 10; PawnPST[55] := 10; PawnPST[56] := 5;
        PawnPST[57] := 0; PawnPST[58] := 0; PawnPST[59] := 0; PawnPST[60] := 0; PawnPST[61] := 0; PawnPST[62] := 0; PawnPST[63] := 0; PawnPST[64] := 0;

        // Knight PST
        KnightPST[1] := -50; KnightPST[2] := -40; KnightPST[3] := -30; KnightPST[4] := -30; KnightPST[5] := -30; KnightPST[6] := -30; KnightPST[7] := -40; KnightPST[8] := -50;
        KnightPST[9] := -40; KnightPST[10] := -20; KnightPST[11] := 0; KnightPST[12] := 0; KnightPST[13] := 0; KnightPST[14] := 0; KnightPST[15] := -20; KnightPST[16] := -40;
        KnightPST[17] := -30; KnightPST[18] := 0; KnightPST[19] := 10; KnightPST[20] := 15; KnightPST[21] := 15; KnightPST[22] := 10; KnightPST[23] := 0; KnightPST[24] := -30;
        KnightPST[25] := -30; KnightPST[26] := 5; KnightPST[27] := 15; KnightPST[28] := 20; KnightPST[29] := 20; KnightPST[30] := 15; KnightPST[31] := 5; KnightPST[32] := -30;
        KnightPST[33] := -30; KnightPST[34] := 0; KnightPST[35] := 15; KnightPST[36] := 20; KnightPST[37] := 20; KnightPST[38] := 15; KnightPST[39] := 0; KnightPST[40] := -30;
        KnightPST[41] := -30; KnightPST[42] := 5; KnightPST[43] := 10; KnightPST[44] := 15; KnightPST[45] := 15; KnightPST[46] := 10; KnightPST[47] := 5; KnightPST[48] := -30;
        KnightPST[49] := -40; KnightPST[50] := -20; KnightPST[51] := 0; KnightPST[52] := 5; KnightPST[53] := 5; KnightPST[54] := 0; KnightPST[55] := -20; KnightPST[56] := -40;
        KnightPST[57] := -50; KnightPST[58] := -40; KnightPST[59] := -30; KnightPST[60] := -30; KnightPST[61] := -30; KnightPST[62] := -30; KnightPST[63] := -40; KnightPST[64] := -50;

        // Bishop PST
        BishopPST[1] := -20; BishopPST[2] := -10; BishopPST[3] := -10; BishopPST[4] := -10; BishopPST[5] := -10; BishopPST[6] := -10; BishopPST[7] := -10; BishopPST[8] := -20;
        BishopPST[9] := -10; BishopPST[10] := 0; BishopPST[11] := 0; BishopPST[12] := 0; BishopPST[13] := 0; BishopPST[14] := 0; BishopPST[15] := 0; BishopPST[16] := -10;
        BishopPST[17] := -10; BishopPST[18] := 0; BishopPST[19] := 5; BishopPST[20] := 10; BishopPST[21] := 10; BishopPST[22] := 5; BishopPST[23] := 0; BishopPST[24] := -10;
        BishopPST[25] := -10; BishopPST[26] := 5; BishopPST[27] := 5; BishopPST[28] := 10; BishopPST[29] := 10; BishopPST[30] := 5; BishopPST[31] := 5; BishopPST[32] := -10;
        BishopPST[33] := -10; BishopPST[34] := 0; BishopPST[35] := 10; BishopPST[36] := 10; BishopPST[37] := 10; BishopPST[38] := 10; BishopPST[39] := 0; BishopPST[40] := -10;
        BishopPST[41] := -10; BishopPST[42] := 10; BishopPST[43] := 10; BishopPST[44] := 10; BishopPST[45] := 10; BishopPST[46] := 10; BishopPST[47] := 10; BishopPST[48] := -10;
        BishopPST[49] := -10; BishopPST[50] := 5; BishopPST[51] := 0; BishopPST[52] := 0; BishopPST[53] := 0; BishopPST[54] := 0; BishopPST[55] := 5; BishopPST[56] := -10;
        BishopPST[57] := -20; BishopPST[58] := -10; BishopPST[59] := -10; BishopPST[60] := -10; BishopPST[61] := -10; BishopPST[62] := -10; BishopPST[63] := -10; BishopPST[64] := -20;

        // Rook PST
        RookPST[1] := 0; RookPST[2] := 0; RookPST[3] := 0; RookPST[4] := 0; RookPST[5] := 0; RookPST[6] := 0; RookPST[7] := 0; RookPST[8] := 0;
        RookPST[9] := 5; RookPST[10] := 10; RookPST[11] := 10; RookPST[12] := 10; RookPST[13] := 10; RookPST[14] := 10; RookPST[15] := 10; RookPST[16] := 5;
        RookPST[17] := -5; RookPST[18] := 0; RookPST[19] := 0; RookPST[20] := 0; RookPST[21] := 0; RookPST[22] := 0; RookPST[23] := 0; RookPST[24] := -5;
        RookPST[25] := -5; RookPST[26] := 0; RookPST[27] := 0; RookPST[28] := 0; RookPST[29] := 0; RookPST[30] := 0; RookPST[31] := 0; RookPST[32] := -5;
        RookPST[33] := -5; RookPST[34] := 0; RookPST[35] := 0; RookPST[36] := 0; RookPST[37] := 0; RookPST[38] := 0; RookPST[39] := 0; RookPST[40] := -5;
        RookPST[41] := -5; RookPST[42] := 0; RookPST[43] := 0; RookPST[44] := 0; RookPST[45] := 0; RookPST[46] := 0; RookPST[47] := 0; RookPST[48] := -5;
        RookPST[49] := -5; RookPST[50] := 0; RookPST[51] := 0; RookPST[52] := 0; RookPST[53] := 0; RookPST[54] := 0; RookPST[55] := 0; RookPST[56] := -5;
        RookPST[57] := 0; RookPST[58] := 0; RookPST[59] := 0; RookPST[60] := 5; RookPST[61] := 5; RookPST[62] := 0; RookPST[63] := 0; RookPST[64] := 0;

        // Queen PST
        QueenPST[1] := -20; QueenPST[2] := -10; QueenPST[3] := -10; QueenPST[4] := -5; QueenPST[5] := -5; QueenPST[6] := -10; QueenPST[7] := -10; QueenPST[8] := -20;
        QueenPST[9] := -10; QueenPST[10] := 0; QueenPST[11] := 0; QueenPST[12] := 0; QueenPST[13] := 0; QueenPST[14] := 0; QueenPST[15] := 0; QueenPST[16] := -10;
        QueenPST[17] := -10; QueenPST[18] := 0; QueenPST[19] := 5; QueenPST[20] := 5; QueenPST[21] := 5; QueenPST[22] := 5; QueenPST[23] := 0; QueenPST[24] := -10;
        QueenPST[25] := -5; QueenPST[26] := 0; QueenPST[27] := 5; QueenPST[28] := 5; QueenPST[29] := 5; QueenPST[30] := 5; QueenPST[31] := 0; QueenPST[32] := -5;
        QueenPST[33] := 0; QueenPST[34] := 0; QueenPST[35] := 5; QueenPST[36] := 5; QueenPST[37] := 5; QueenPST[38] := 5; QueenPST[39] := 0; QueenPST[40] := -5;
        QueenPST[41] := -10; QueenPST[42] := 5; QueenPST[43] := 5; QueenPST[44] := 5; QueenPST[45] := 5; QueenPST[46] := 5; QueenPST[47] := 0; QueenPST[48] := -10;
        QueenPST[49] := -10; QueenPST[50] := 0; QueenPST[51] := 5; QueenPST[52] := 0; QueenPST[53] := 0; QueenPST[54] := 0; QueenPST[55] := 0; QueenPST[56] := -10;
        QueenPST[57] := -20; QueenPST[58] := -10; QueenPST[59] := -10; QueenPST[60] := -5; QueenPST[61] := -5; QueenPST[62] := -10; QueenPST[63] := -10; QueenPST[64] := -20;

        // King Middlegame PST
        KingMidPST[1] := -30; KingMidPST[2] := -40; KingMidPST[3] := -40; KingMidPST[4] := -50; KingMidPST[5] := -50; KingMidPST[6] := -40; KingMidPST[7] := -40; KingMidPST[8] := -30;
        KingMidPST[9] := -30; KingMidPST[10] := -40; KingMidPST[11] := -40; KingMidPST[12] := -50; KingMidPST[13] := -50; KingMidPST[14] := -40; KingMidPST[15] := -40; KingMidPST[16] := -30;
        KingMidPST[17] := -30; KingMidPST[18] := -40; KingMidPST[19] := -40; KingMidPST[20] := -50; KingMidPST[21] := -50; KingMidPST[22] := -40; KingMidPST[23] := -40; KingMidPST[24] := -30;
        KingMidPST[25] := -30; KingMidPST[26] := -40; KingMidPST[27] := -40; KingMidPST[28] := -50; KingMidPST[29] := -50; KingMidPST[30] := -40; KingMidPST[31] := -40; KingMidPST[32] := -30;
        KingMidPST[33] := -20; KingMidPST[34] := -30; KingMidPST[35] := -30; KingMidPST[36] := -40; KingMidPST[37] := -40; KingMidPST[38] := -30; KingMidPST[39] := -30; KingMidPST[40] := -20;
        KingMidPST[41] := -10; KingMidPST[42] := -20; KingMidPST[43] := -20; KingMidPST[44] := -20; KingMidPST[45] := -20; KingMidPST[46] := -20; KingMidPST[47] := -20; KingMidPST[48] := -10;
        KingMidPST[49] := 20; KingMidPST[50] := 20; KingMidPST[51] := 0; KingMidPST[52] := 0; KingMidPST[53] := 0; KingMidPST[54] := 0; KingMidPST[55] := 20; KingMidPST[56] := 20;
        KingMidPST[57] := 20; KingMidPST[58] := 30; KingMidPST[59] := 10; KingMidPST[60] := 0; KingMidPST[61] := 0; KingMidPST[62] := 10; KingMidPST[63] := 30; KingMidPST[64] := 20;

        // King Endgame PST
        KingEndPST[1] := -50; KingEndPST[2] := -40; KingEndPST[3] := -30; KingEndPST[4] := -20; KingEndPST[5] := -20; KingEndPST[6] := -30; KingEndPST[7] := -40; KingEndPST[8] := -50;
        KingEndPST[9] := -30; KingEndPST[10] := -20; KingEndPST[11] := -10; KingEndPST[12] := 0; KingEndPST[13] := 0; KingEndPST[14] := -10; KingEndPST[15] := -20; KingEndPST[16] := -30;
        KingEndPST[17] := -30; KingEndPST[18] := -10; KingEndPST[19] := 20; KingEndPST[20] := 30; KingEndPST[21] := 30; KingEndPST[22] := 20; KingEndPST[23] := -10; KingEndPST[24] := -30;
        KingEndPST[25] := -30; KingEndPST[26] := -10; KingEndPST[27] := 30; KingEndPST[28] := 40; KingEndPST[29] := 40; KingEndPST[30] := 30; KingEndPST[31] := -10; KingEndPST[32] := -30;
        KingEndPST[33] := -30; KingEndPST[34] := -10; KingEndPST[35] := 30; KingEndPST[36] := 40; KingEndPST[37] := 40; KingEndPST[38] := 30; KingEndPST[39] := -10; KingEndPST[40] := -30;
        KingEndPST[41] := -30; KingEndPST[42] := -10; KingEndPST[43] := 20; KingEndPST[44] := 30; KingEndPST[45] := 30; KingEndPST[46] := 20; KingEndPST[47] := -10; KingEndPST[48] := -30;
        KingEndPST[49] := -30; KingEndPST[50] := -30; KingEndPST[51] := 0; KingEndPST[52] := 0; KingEndPST[53] := 0; KingEndPST[54] := 0; KingEndPST[55] := -30; KingEndPST[56] := -30;
        KingEndPST[57] := -50; KingEndPST[58] := -30; KingEndPST[59] := -30; KingEndPST[60] := -30; KingEndPST[61] := -30; KingEndPST[62] := -30; KingEndPST[63] := -30; KingEndPST[64] := -50;
    end;

    local procedure GetPSTValue(Piece: Integer; Sq: Integer): Integer
    var
        AbsP: Integer;
        MirrorSq: Integer;
        Row: Integer;
        MirrorRow: Integer;
        Col: Integer;
    begin
        AbsP := AbsPiece(Piece);

        // For black pieces, mirror the square vertically
        if Piece > 0 then
            MirrorSq := Sq
        else begin
            Row := GetRow(Sq);
            Col := GetCol(Sq);
            MirrorRow := 7 - Row;
            MirrorSq := SquareFromRC(MirrorRow, Col);
        end;

        case AbsP of
            1:
                exit(PawnPST[MirrorSq]);
            2:
                exit(KnightPST[MirrorSq]);
            3:
                exit(BishopPST[MirrorSq]);
            4:
                exit(RookPST[MirrorSq]);
            5:
                exit(QueenPST[MirrorSq]);
            6:
                exit(GetKingPSTValue(MirrorSq));
        end;
        exit(0);
    end;

    local procedure GetKingPSTValue(Sq: Integer): Integer
    var
        Phase: Integer;
        MidVal: Integer;
        EndVal: Integer;
        TotalPhase: Integer;
    begin
        // Calculate game phase based on material
        Phase := CalcGamePhase();
        TotalPhase := 24;  // Max phase (2*N + 2*B + 4*R + 2*Q = 2*1 + 2*1 + 4*2 + 2*4 = 24 ... simplified)
        if Phase > TotalPhase then
            Phase := TotalPhase;

        MidVal := KingMidPST[Sq];
        EndVal := KingEndPST[Sq];

        // Interpolate
        exit((MidVal * Phase + EndVal * (TotalPhase - Phase)) div TotalPhase);
    end;

    local procedure CalcGamePhase(): Integer
    var
        Phase: Integer;
        i: Integer;
        AbsP: Integer;
    begin
        Phase := 0;
        for i := 1 to 64 do begin
            AbsP := AbsPiece(Board[i]);
            case AbsP of
                2:
                    Phase += 1;
                3:
                    Phase += 1;
                4:
                    Phase += 2;
                5:
                    Phase += 4;
            end;
        end;
        exit(Phase);
    end;

    local procedure MaterialValue(Piece: Integer): Integer
    begin
        case AbsPiece(Piece) of
            1:
                exit(100);
            2:
                exit(320);
            3:
                exit(330);
            4:
                exit(500);
            5:
                exit(900);
            6:
                exit(20000);
        end;
        exit(0);
    end;

    local procedure Evaluate(): Integer
    var
        Score: Integer;
        i: Integer;
        Piece: Integer;
    begin
        Score := 0;
        for i := 1 to 64 do begin
            Piece := Board[i];
            if Piece = 0 then
                continue;
            if Piece > 0 then begin
                Score += MaterialValue(Piece);
                Score += GetPSTValue(Piece, i);
            end else begin
                Score -= MaterialValue(Piece);
                Score -= GetPSTValue(Piece, i);
            end;
        end;

        // Return from perspective of side to move
        if WhiteToMove then
            exit(Score)
        else
            exit(-Score);
    end;

    // ===== MOVE NOTATION =====

    local procedure ComputeMoveNotation(Move: Integer): Text
    var
        FromSq: Integer;
        ToSq: Integer;
        Flag: Integer;
        Piece: Integer;
        AbsP: Integer;
        Notation: Text;
        IsCapture: Boolean;
    begin
        FromSq := GetFrom(Move);
        ToSq := GetTo(Move);
        Flag := GetFlag(Move);
        Piece := Board[FromSq];
        AbsP := AbsPiece(Piece);

        // Castling
        if Flag = 2 then begin
            if GetCol(ToSq) > GetCol(FromSq) then
                exit('O-O')
            else
                exit('O-O-O');
        end;

        IsCapture := (Board[ToSq] <> 0) or (Flag = 1);
        Notation := '';

        // Piece prefix
        case AbsP of
            2:
                Notation := 'N';
            3:
                Notation := 'B';
            4:
                Notation := 'R';
            5:
                Notation := 'Q';
            6:
                Notation := 'K';
        end;

        // Disambiguation for N, B, R, Q
        if (AbsP >= 2) and (AbsP <= 5) then
            Notation += GetDisambiguation(FromSq, ToSq, Piece);

        // Pawn captures include from-file
        if (AbsP = 1) and IsCapture then
            Notation += ColToFile(GetCol(FromSq));

        if IsCapture then
            Notation += 'x';

        Notation += ColToFile(GetCol(ToSq));
        Notation += RowToRank(GetRow(ToSq));

        // Promotion
        case Flag of
            3:
                Notation += '=N';
            4:
                Notation += '=B';
            5:
                Notation += '=R';
            6:
                Notation += '=Q';
        end;

        exit(Notation);
    end;

    local procedure GetDisambiguation(FromSq: Integer; ToSq: Integer; Piece: Integer): Text
    var
        i: Integer;
        NeedDisambig: Boolean;
        SameFile: Boolean;
        SameRank: Boolean;
    begin
        NeedDisambig := false;
        SameFile := false;
        SameRank := false;

        for i := 1 to 64 do begin
            if (i <> FromSq) and (Board[i] = Piece) then begin
                NeedDisambig := true;
                if GetCol(i) = GetCol(FromSq) then
                    SameFile := true;
                if GetRow(i) = GetRow(FromSq) then
                    SameRank := true;
            end;
        end;

        if not NeedDisambig then
            exit('');

        if not SameFile then
            exit(ColToFile(GetCol(FromSq)));
        if not SameRank then
            exit(RowToRank(GetRow(FromSq)));
        exit(ColToFile(GetCol(FromSq)) + RowToRank(GetRow(FromSq)));
    end;

    local procedure ColToFile(Col: Integer): Text
    begin
        case Col of
            0:
                exit('a');
            1:
                exit('b');
            2:
                exit('c');
            3:
                exit('d');
            4:
                exit('e');
            5:
                exit('f');
            6:
                exit('g');
            7:
                exit('h');
        end;
        exit('?');
    end;

    local procedure RowToRank(Row: Integer): Text
    begin
        // Row 0 = rank 8, Row 7 = rank 1
        exit(Format(8 - Row));
    end;

    local procedure AppendCheckSuffix()
    begin
        if (GameState = 1) or (GameState = 2) then
            LastMoveNotation += '#'
        else if (GameState = 0) and IsCurrentSideInCheck() then
            LastMoveNotation += '+';
    end;

    // ===== SEARCH =====

    local procedure FindBestMove(): Integer
    var
        Moves: array[256] of Integer;
        MoveCount: Integer;
        BestMove: Integer;
        BestScore: Integer;
        Score: Integer;
        i: Integer;
        SearchDepth: Integer;
    begin
        SearchDepth := 3;
        GenerateLegalMoves(Moves, MoveCount);

        if MoveCount = 0 then
            exit(0);

        if MoveCount = 1 then
            exit(Moves[1]);

        BestScore := -99999;
        BestMove := Moves[1];

        for i := 1 to MoveCount do begin
            SaveState(2);
            MakeMove(Moves[i]);
            Score := -Negamax(SearchDepth - 1, -99999, -BestScore, 3);
            RestoreState(2);

            if Score > BestScore then begin
                BestScore := Score;
                BestMove := Moves[i];
            end;
        end;

        exit(BestMove);
    end;

    local procedure Negamax(Depth: Integer; Alpha: Integer; Beta: Integer; SaveDepth: Integer): Integer
    var
        Moves: array[256] of Integer;
        MoveCount: Integer;
        Score: Integer;
        i: Integer;
        BestScore: Integer;
        KingSq: Integer;
    begin
        if Depth = 0 then
            exit(Evaluate());

        GenerateLegalMoves(Moves, MoveCount);

        if MoveCount = 0 then begin
            // Check if in check (checkmate) or not (stalemate)
            if WhiteToMove then
                KingSq := WhiteKingSq
            else
                KingSq := BlackKingSq;

            if IsSquareAttacked(KingSq, not WhiteToMove) then
                exit(-20000 - Depth)  // Checkmate, prefer faster mates
            else
                exit(0);  // Stalemate
        end;

        BestScore := -99999;

        for i := 1 to MoveCount do begin
            SaveState(SaveDepth);
            MakeMove(Moves[i]);
            Score := -Negamax(Depth - 1, -Beta, -Alpha, SaveDepth + 1);
            RestoreState(SaveDepth);

            if Score > BestScore then
                BestScore := Score;

            if Score > Alpha then
                Alpha := Score;

            if Alpha >= Beta then
                break;
        end;

        exit(BestScore);
    end;

    // ===== GAME STATE =====

    local procedure UpdateGameState()
    var
        Moves: array[256] of Integer;
        MoveCount: Integer;
        InCheck: Boolean;
        KingSq: Integer;
    begin
        GenerateLegalMoves(Moves, MoveCount);

        if WhiteToMove then
            KingSq := WhiteKingSq
        else
            KingSq := BlackKingSq;

        InCheck := IsSquareAttacked(KingSq, not WhiteToMove);

        if MoveCount = 0 then begin
            if InCheck then begin
                // Checkmate
                if WhiteToMove then
                    GameState := 2   // Black wins (white is mated)
                else
                    GameState := 1;  // White wins (black is mated)
            end else
                GameState := 3;  // Stalemate
        end else if HalfMoveClock >= 100 then
            GameState := 4  // 50-move rule draw
        else
            GameState := 0;
    end;
}
