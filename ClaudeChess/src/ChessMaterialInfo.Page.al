page 53106 "Chess Material Info"
{
    PageType = CardPart;
    SourceTable = "Chess Material Info";
    SourceTableTemporary = true;
    Caption = 'Material';
    ShowFilter = false;
    LinksAllowed = false;

    layout
    {
        area(content)
        {
            field("Balance"; Rec."Balance")
            {
                ApplicationArea = All;
                Caption = 'Balance';
                StyleExpr = BalanceStyle;
                Style = Strong;
            }
            field("White Captures"; Rec."White Captures")
            {
                ApplicationArea = All;
                Caption = 'White captured';
            }
            field("Black Captures"; Rec."Black Captures")
            {
                ApplicationArea = All;
                Caption = 'Black captured';
            }
        }
    }

    var
        BalanceStyle: Text;

    procedure UpdateMaterial(WhiteCaptures: Text; BlackCaptures: Text; BalanceText: Text)
    begin
        if not Rec.Get(1) then begin
            Rec.Init();
            Rec."Entry No." := 1;
            Rec.Insert();
        end;
        Rec."White Captures" := CopyStr(WhiteCaptures, 1, MaxStrLen(Rec."White Captures"));
        Rec."Black Captures" := CopyStr(BlackCaptures, 1, MaxStrLen(Rec."Black Captures"));
        Rec."Balance" := CopyStr(BalanceText, 1, MaxStrLen(Rec."Balance"));
        Rec.Modify();

        if BalanceText.StartsWith('+') then
            BalanceStyle := 'Favorable'
        else if BalanceText.StartsWith('-') then
            BalanceStyle := 'Unfavorable'
        else
            BalanceStyle := 'Standard';

        CurrPage.Update(false);
    end;

    procedure ClearMaterial()
    begin
        Rec.DeleteAll();
        CurrPage.Update(false);
    end;
}
