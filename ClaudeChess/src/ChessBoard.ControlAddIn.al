controladdin ChessBoard
{
    RequestedHeight = 700;
    RequestedWidth = 600;
    MinimumHeight = 500;
    MinimumWidth = 400;
    HorizontalStretch = true;
    VerticalStretch = true;

    Scripts = 'controladdin/chess/chessboard.js', 'controladdin/chess/startup.js';
    StyleSheets = 'controladdin/chess/chessboard.css';

    // AL calls JS
    procedure InitializeBoard(BoardState: Text; PlayerIsWhite: Boolean);
    procedure UpdatePosition(BoardState: Text; LastFrom: Integer; LastTo: Integer; CheckSquare: Integer);
    procedure MakeComputerMove(FromSquare: Integer; ToSquare: Integer; PromotionPiece: Text);
    procedure GameOver(ResultText: Text);
    procedure ShowLegalMoves(LegalSquares: Text);
    procedure SetStatus(StatusText: Text);
    procedure RequestEngineMove(DelayMs: Integer);

    // JS calls AL
    event OnControlReady();
    event OnSquareSelected(SquareIndex: Integer);
    event OnMoveMade(FromSquare: Integer; ToSquare: Integer);
    event OnPromotionSelected(FromSquare: Integer; ToSquare: Integer; PieceChoice: Text);
    event OnEngineThinkRequest();
}
