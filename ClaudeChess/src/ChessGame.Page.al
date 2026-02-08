page 53100 "Chess Game"
{
    PageType = Card;
    Caption = 'Claude Chess';
    ApplicationArea = All;
    UsageCategory = Tasks;

    layout
    {
        area(content)
        {
            usercontrol(ChessBoard; ChessBoard)
            {
                ApplicationArea = All;

                trigger OnControlReady()
                begin
                    ControlReady := true;
                    StartNewGame();
                end;

                trigger OnSquareSelected(SquareIndex: Integer)
                var
                    LegalMoves: Text;
                begin
                    if not GameActive then
                        exit;

                    LegalMoves := ChessEngine.GetLegalMoves(SquareIndex);
                    CurrPage.ChessBoard.ShowLegalMoves(LegalMoves);
                end;

                trigger OnMoveMade(FromSquare: Integer; ToSquare: Integer)
                begin
                    HandlePlayerMove(FromSquare, ToSquare, 0);
                end;

                trigger OnPromotionSelected(FromSquare: Integer; ToSquare: Integer; PieceChoice: Text)
                var
                    PromoPiece: Integer;
                begin
                    case PieceChoice of
                        'N':
                            PromoPiece := 2;
                        'B':
                            PromoPiece := 3;
                        'R':
                            PromoPiece := 4;
                        'Q':
                            PromoPiece := 5;
                        else
                            PromoPiece := 5;
                    end;
                    HandlePlayerMove(FromSquare, ToSquare, PromoPiece);
                end;

                trigger OnEngineThinkRequest()
                begin
                    HandleEngineResponse();
                end;
            }
        }
        area(factboxes)
        {
            part(MaterialInfo; "Chess Material Info")
            {
                ApplicationArea = All;
                Caption = 'Material';
            }
            part(MoveHistory; "Chess Move History")
            {
                ApplicationArea = All;
                Caption = 'Moves';
            }
        }
    }

    actions
    {
        area(Processing)
        {
            action(NewGame)
            {
                ApplicationArea = All;
                Caption = 'New Game';
                Image = Start;
                Promoted = true;
                PromotedCategory = Process;
                PromotedIsBig = true;

                trigger OnAction()
                begin
                    if ControlReady then
                        StartNewGame();
                end;
            }

            action(Resign)
            {
                ApplicationArea = All;
                Caption = 'Resign';
                Image = Stop;
                Promoted = true;
                PromotedCategory = Process;

                trigger OnAction()
                begin
                    if GameActive then begin
                        GameActive := false;
                        CurrPage.ChessBoard.GameOver('You resigned. Black wins!');
                        CurrPage.ChessBoard.SetStatus('Game Over - You resigned');
                    end;
                end;
            }
        }
    }

    var
        ChessEngine: Codeunit "Chess Engine";
        ControlReady: Boolean;
        GameActive: Boolean;
        MoveNumber: Integer;

    local procedure StartNewGame()
    begin
        ChessEngine.NewGame();
        GameActive := true;
        MoveNumber := 1;
        CurrPage.MoveHistory.Page.ClearMoves();
        CurrPage.MaterialInfo.Page.ClearMaterial();
        CurrPage.ChessBoard.InitializeBoard(ChessEngine.GetBoardString(), true);
        CurrPage.ChessBoard.SetStatus('Your turn - White to move');
    end;

    local procedure HandlePlayerMove(FromSquare: Integer; ToSquare: Integer; PromotionPiece: Integer)
    var
        MoveApplied: Boolean;
        CheckSq: Integer;
        StateResult: Integer;
    begin
        if not GameActive then
            exit;

        MoveApplied := ChessEngine.ApplyPlayerMove(FromSquare, ToSquare, PromotionPiece);
        if not MoveApplied then
            exit;

        // Add white move to history
        CurrPage.MoveHistory.Page.AddWhiteMove(MoveNumber, ChessEngine.GetLastMoveNotation());

        // Update material display
        UpdateMaterialDisplay();

        // Determine check square for highlight
        CheckSq := -1;
        if ChessEngine.IsCurrentSideInCheck() then
            CheckSq := ChessEngine.GetKingSquare0(false);  // Black king in check

        // Update board with player move highlights
        CurrPage.ChessBoard.UpdatePosition(ChessEngine.GetBoardString(), FromSquare, ToSquare, CheckSq);

        // Check game state after player move
        StateResult := ChessEngine.GetGameState();
        if StateResult <> 0 then begin
            GameActive := false;
            ShowGameResult(StateResult);
            exit;
        end;

        // Request engine move with 1 second delay
        CurrPage.ChessBoard.SetStatus('Engine is thinking...');
        CurrPage.ChessBoard.RequestEngineMove(1000);
    end;

    local procedure HandleEngineResponse()
    var
        EngineMove: Integer;
        EngineFrom: Integer;
        EngineTo: Integer;
        CheckSq: Integer;
        StateResult: Integer;
    begin
        if not GameActive then
            exit;

        // Engine computes its move
        EngineMove := ChessEngine.ComputeEngineMove();
        if EngineMove = 0 then begin
            GameActive := false;
            CurrPage.ChessBoard.SetStatus('Engine has no moves');
            exit;
        end;

        EngineFrom := ChessEngine.GetMoveFrom(EngineMove);
        EngineTo := ChessEngine.GetMoveTo(EngineMove);

        // Add black move to history
        CurrPage.MoveHistory.Page.SetBlackMove(MoveNumber, ChessEngine.GetLastMoveNotation());

        // Update material display
        UpdateMaterialDisplay();

        // Determine check square for highlight
        CheckSq := -1;
        if ChessEngine.IsCurrentSideInCheck() then
            CheckSq := ChessEngine.GetKingSquare0(true);  // White king in check

        // Update board with engine move highlights
        CurrPage.ChessBoard.UpdatePosition(ChessEngine.GetBoardString(), EngineFrom, EngineTo, CheckSq);

        // Check game state after engine move
        StateResult := ChessEngine.GetGameState();
        if StateResult <> 0 then begin
            GameActive := false;
            ShowGameResult(StateResult);
            exit;
        end;

        MoveNumber += 1;

        // Player's turn
        if ChessEngine.IsCurrentSideInCheck() then
            CurrPage.ChessBoard.SetStatus('Your turn - You are in check!')
        else
            CurrPage.ChessBoard.SetStatus('Your turn - White to move');
    end;

    local procedure UpdateMaterialDisplay()
    var
        WhiteCap: Text;
        BlackCap: Text;
        BalanceCP: Integer;
        AbsBalance: Integer;
        BalanceText: Text;
    begin
        WhiteCap := ChessEngine.GetCapturedPieces(true);
        BlackCap := ChessEngine.GetCapturedPieces(false);
        BalanceCP := ChessEngine.GetMaterialBalance();

        if BalanceCP = 0 then
            BalanceText := 'Even'
        else begin
            if BalanceCP > 0 then begin
                AbsBalance := BalanceCP;
                BalanceText := '+';
            end else begin
                AbsBalance := -BalanceCP;
                BalanceText := '-';
            end;
            BalanceText += Format(AbsBalance div 100);
            BalanceText += '.';
            BalanceText += Format((AbsBalance mod 100) div 10);
        end;

        CurrPage.MaterialInfo.Page.UpdateMaterial(WhiteCap, BlackCap, BalanceText);
    end;

    local procedure ShowGameResult(State: Integer)
    var
        ResultText: Text;
    begin
        case State of
            1:
                begin
                    ResultText := 'Checkmate! White wins!';
                    CurrPage.ChessBoard.SetStatus('Game Over - White wins');
                end;
            2:
                begin
                    ResultText := 'Checkmate! Black wins!';
                    CurrPage.ChessBoard.SetStatus('Game Over - Black wins');
                end;
            3:
                begin
                    ResultText := 'Stalemate - Draw!';
                    CurrPage.ChessBoard.SetStatus('Game Over - Stalemate');
                end;
            4:
                begin
                    ResultText := 'Draw by 50-move rule!';
                    CurrPage.ChessBoard.SetStatus('Game Over - Draw');
                end;
        end;
        CurrPage.ChessBoard.GameOver(ResultText);
    end;
}
