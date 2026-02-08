page 53104 "Chess Move History"
{
    PageType = ListPart;
    SourceTable = "Chess Move";
    SourceTableTemporary = true;
    Editable = false;
    Caption = 'Moves';
    ShowFilter = false;
    LinksAllowed = false;

    layout
    {
        area(content)
        {
            repeater(Moves)
            {
                field("Move No."; Rec."Move No.")
                {
                    ApplicationArea = All;
                    Caption = '#';
                    Style = Strong;
                }
                field("White Move"; Rec."White Move")
                {
                    ApplicationArea = All;
                    Caption = 'White';
                }
                field("Black Move"; Rec."Black Move")
                {
                    ApplicationArea = All;
                    Caption = 'Black';
                }
            }
        }
    }

    procedure AddWhiteMove(MoveNum: Integer; MoveText: Text)
    begin
        Rec.Init();
        Rec."Entry No." := MoveNum;
        Rec."Move No." := MoveNum;
        Rec."White Move" := CopyStr(MoveText, 1, MaxStrLen(Rec."White Move"));
        Rec.Insert();
        CurrPage.Update(false);
    end;

    procedure SetBlackMove(MoveNum: Integer; MoveText: Text)
    begin
        if Rec.Get(MoveNum) then begin
            Rec."Black Move" := CopyStr(MoveText, 1, MaxStrLen(Rec."Black Move"));
            Rec.Modify();
            CurrPage.Update(false);
        end;
    end;

    procedure ClearMoves()
    begin
        Rec.DeleteAll();
        CurrPage.Update(false);
    end;
}
