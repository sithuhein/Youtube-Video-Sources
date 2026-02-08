var ChessBoard = (function () {
    var boardState = '';
    var playerIsWhite = true;
    var selectedSquare = -1;
    var legalTargets = [];
    var lastMoveFrom = -1;
    var lastMoveTo = -1;
    var gameActive = false;
    var waitingForEngine = false;
    var checkSquare = -1;

    var pieceMap = {
        'P': '\u2659', 'N': '\u2658', 'B': '\u2657', 'R': '\u2656', 'Q': '\u2655', 'K': '\u2654',
        'p': '\u265F', 'n': '\u265E', 'b': '\u265D', 'r': '\u265C', 'q': '\u265B', 'k': '\u265A'
    };

    var pendingFrom = -1;
    var pendingTo = -1;

    function createBoard() {
        var container = document.getElementById('controlAddIn');
        container.innerHTML = '';

        var wrapper = document.createElement('div');
        wrapper.id = 'chess-container';

        var boardDiv = document.createElement('div');
        boardDiv.id = 'chess-board';
        boardDiv.style.position = 'relative';

        for (var i = 0; i < 64; i++) {
            var sq = document.createElement('div');
            sq.className = 'square';
            var row = Math.floor(i / 8);
            var col = i % 8;
            if ((row + col) % 2 === 0) {
                sq.className += ' square-light';
            } else {
                sq.className += ' square-dark';
            }
            sq.setAttribute('data-index', i);
            sq.addEventListener('click', onSquareClick);
            boardDiv.appendChild(sq);
        }

        var gameOverOverlay = document.createElement('div');
        gameOverOverlay.id = 'game-over-overlay';
        var gameOverText = document.createElement('div');
        gameOverText.id = 'game-over-text';
        gameOverOverlay.appendChild(gameOverText);
        boardDiv.appendChild(gameOverOverlay);

        wrapper.appendChild(boardDiv);

        var statusBar = document.createElement('div');
        statusBar.id = 'status-bar';
        statusBar.textContent = 'Welcome to Claude Chess!';
        wrapper.appendChild(statusBar);

        var promoOverlay = document.createElement('div');
        promoOverlay.id = 'promotion-overlay';
        var promoDialog = document.createElement('div');
        promoDialog.id = 'promotion-dialog';
        var promoTitle = document.createElement('h3');
        promoTitle.textContent = 'Choose promotion piece:';
        promoDialog.appendChild(promoTitle);
        var promoPieces = document.createElement('div');
        promoPieces.className = 'promotion-pieces';
        promoDialog.appendChild(promoPieces);
        promoOverlay.appendChild(promoDialog);
        wrapper.appendChild(promoOverlay);

        container.appendChild(wrapper);
    }

    function renderBoard() {
        var squares = document.querySelectorAll('#chess-board .square');
        for (var i = 0; i < 64; i++) {
            var sq = squares[i];
            var row = Math.floor(i / 8);
            var col = i % 8;

            // Reset classes
            sq.className = 'square';
            if ((row + col) % 2 === 0) {
                sq.className += ' square-light';
            } else {
                sq.className += ' square-dark';
            }

            // Highlights
            if (i === selectedSquare) {
                sq.className += ' selected';
            }
            if (i === lastMoveFrom || i === lastMoveTo) {
                sq.className += ' last-move';
            }
            if (i === checkSquare) {
                sq.className += ' in-check';
            }

            // Piece
            var ch = boardState.charAt(i);
            sq.innerHTML = '';
            if (ch && ch !== '.') {
                sq.textContent = pieceMap[ch] || '';
            }

            // Legal move indicators
            if (legalTargets.indexOf(i) >= 0) {
                var indicator = document.createElement('div');
                var targetCh = boardState.charAt(i);
                if (targetCh && targetCh !== '.') {
                    indicator.className = 'legal-capture';
                } else {
                    indicator.className = 'legal-dot';
                }
                sq.appendChild(indicator);
            }
        }
    }

    function onSquareClick(e) {
        if (!gameActive || waitingForEngine) return;

        var target = e.currentTarget;
        var idx = parseInt(target.getAttribute('data-index'));

        if (selectedSquare >= 0 && legalTargets.indexOf(idx) >= 0) {
            // Move to legal target
            var fromSq = selectedSquare;
            clearSelection();

            // Check for promotion
            var piece = boardState.charAt(fromSq);
            var toRow = Math.floor(idx / 8);
            if ((piece === 'P' && toRow === 0) || (piece === 'p' && toRow === 7)) {
                showPromotionDialog(fromSq, idx, piece === 'P');
                return;
            }

            Microsoft.Dynamics.NAV.InvokeExtensibilityMethod('OnMoveMade', [fromSq, idx]);
        } else {
            // Select a piece
            var ch = boardState.charAt(idx);
            if (ch === '.') {
                clearSelection();
                renderBoard();
                return;
            }

            // Only allow selecting own pieces
            var isWhitePiece = ch === ch.toUpperCase() && ch !== '.';
            if (playerIsWhite && !isWhitePiece) {
                clearSelection();
                renderBoard();
                return;
            }
            if (!playerIsWhite && isWhitePiece) {
                clearSelection();
                renderBoard();
                return;
            }

            selectedSquare = idx;
            legalTargets = [];
            renderBoard();
            Microsoft.Dynamics.NAV.InvokeExtensibilityMethod('OnSquareSelected', [idx]);
        }
    }

    function clearSelection() {
        selectedSquare = -1;
        legalTargets = [];
    }

    function showPromotionDialog(fromSq, toSq, isWhite) {
        pendingFrom = fromSq;
        pendingTo = toSq;
        var overlay = document.getElementById('promotion-overlay');
        var piecesDiv = overlay.querySelector('.promotion-pieces');
        piecesDiv.innerHTML = '';

        var options = isWhite ? ['Q', 'R', 'B', 'N'] : ['q', 'r', 'b', 'n'];
        var names = ['Q', 'R', 'B', 'N'];

        for (var i = 0; i < 4; i++) {
            var btn = document.createElement('div');
            btn.className = 'promotion-piece';
            btn.textContent = pieceMap[options[i]];
            btn.setAttribute('data-piece', names[i]);
            btn.addEventListener('click', onPromotionChoice);
            piecesDiv.appendChild(btn);
        }

        overlay.style.display = 'flex';
    }

    function onPromotionChoice(e) {
        var piece = e.currentTarget.getAttribute('data-piece');
        document.getElementById('promotion-overlay').style.display = 'none';
        Microsoft.Dynamics.NAV.InvokeExtensibilityMethod('OnPromotionSelected', [pendingFrom, pendingTo, piece]);
    }

    // Public API called from AL

    function InitializeBoard(state, isWhite) {
        boardState = state;
        playerIsWhite = isWhite;
        selectedSquare = -1;
        legalTargets = [];
        lastMoveFrom = -1;
        lastMoveTo = -1;
        checkSquare = -1;
        gameActive = true;
        waitingForEngine = false;

        createBoard();
        renderBoard();
    }

    function UpdatePosition(state, lastFrom, lastTo, checkSq) {
        boardState = state;
        lastMoveFrom = lastFrom;
        lastMoveTo = lastTo;
        checkSquare = checkSq;
        selectedSquare = -1;
        legalTargets = [];
        waitingForEngine = false;
        renderBoard();
    }

    function MakeComputerMove(fromSquare, toSquare, promotionPiece) {
        lastMoveFrom = fromSquare;
        lastMoveTo = toSquare;
        waitingForEngine = false;
    }

    function RequestEngineMove(delayMs) {
        waitingForEngine = true;
        setTimeout(function () {
            Microsoft.Dynamics.NAV.InvokeExtensibilityMethod('OnEngineThinkRequest', []);
        }, delayMs);
    }

    function GameOver(resultText) {
        gameActive = false;
        waitingForEngine = false;
        clearSelection();
        var overlay = document.getElementById('game-over-overlay');
        var text = document.getElementById('game-over-text');
        text.textContent = resultText;
        overlay.style.display = 'flex';
    }

    function ShowLegalMoves(legalSquares) {
        legalTargets = [];
        if (legalSquares && legalSquares.length > 0) {
            var parts = legalSquares.split(',');
            for (var i = 0; i < parts.length; i++) {
                var val = parseInt(parts[i].trim());
                if (!isNaN(val)) {
                    legalTargets.push(val);
                }
            }
        }
        renderBoard();
    }

    function SetStatus(statusText) {
        var bar = document.getElementById('status-bar');
        if (bar) {
            bar.textContent = statusText;
        }
    }

    return {
        InitializeBoard: InitializeBoard,
        UpdatePosition: UpdatePosition,
        MakeComputerMove: MakeComputerMove,
        RequestEngineMove: RequestEngineMove,
        GameOver: GameOver,
        ShowLegalMoves: ShowLegalMoves,
        SetStatus: SetStatus
    };
})();

// Wire up AL -> JS calls
function InitializeBoard(boardState, playerIsWhite) {
    ChessBoard.InitializeBoard(boardState, playerIsWhite);
}

function UpdatePosition(boardState, lastFrom, lastTo, checkSquare) {
    ChessBoard.UpdatePosition(boardState, lastFrom, lastTo, checkSquare);
}

function MakeComputerMove(fromSquare, toSquare, promotionPiece) {
    ChessBoard.MakeComputerMove(fromSquare, toSquare, promotionPiece);
}

function RequestEngineMove(delayMs) {
    ChessBoard.RequestEngineMove(delayMs);
}

function GameOver(resultText) {
    ChessBoard.GameOver(resultText);
}

function ShowLegalMoves(legalSquares) {
    ChessBoard.ShowLegalMoves(legalSquares);
}

function SetStatus(statusText) {
    ChessBoard.SetStatus(statusText);
}
