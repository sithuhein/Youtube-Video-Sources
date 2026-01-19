// Welcome to your new AL extension.
// Remember that object names and IDs should be unique across all extensions.
// AL snippets start with t*, like tpageext - give them a try and happy coding!

namespace DefaultPublisher.ELI5DefensiveAL;

using Microsoft.Sales.Customer;
using Microsoft.Finance.GeneralLedger.Account;
using Microsoft.Finance.SalesTax;
using Microsoft.Finance.Analysis;

pageextension 50100 CustomerListExt extends "Customer List"
{

    trigger OnOpenPage();
    var
        Result: Boolean;
        Done: Boolean;
        d: Date;
        DayNo: Integer;
        Month: Integer;
        Year: Integer;
    begin
        Done := true;

        DayNo := 29;
        Month := 2;
        Year := 2001;



        if not CreateDate(DayNo, Month, Year, D) then
            message('Wrong Date!');

        // repeat
        //     result := insertstuff();   
        //     if not result then begin
        //         // Insert failure log
        //         //GetLastErrorText()
        //     end;
        // until Done;



    end;

    [TryFunction]
    procedure CreateDate(d: integer; m: integer; y: integer; var outdate: Date)
    begin
        outdate := DMY2Date(d, m, y);
    end;

    [TryFunction]
    procedure insertstuff()
    var
        CPG: Record "Customer Posting Group";
        x: Text;
    begin
        CPG.Init();
        CPG.validate(ImportantAccount, copystr(x, 1, MaxStrLen(CPG.ImportantAccount)));
        CPG.Insert();
    end;
}
tableextension 50100 "CPG" extends "Customer Posting Group"
{
    fields
    {
        field(50100; ImportantAccount; Code[20])
        {
            Caption = 'Important Account';
            DataClassification = SystemMetadata;
            TableRelation = "G/L Account"."No." where("Account Type" = const(Total));
            NotBlank = true;
            trigger OnValidate()
            var
                GL: Record "G/L Account";
                TGC: Record "Tax Group";
            begin
                GL.Get(ImportantAccount);
                if not (GL."Account Type" = GL."Account Type"::Total) then
                    error('Not Total account type');
                if GL.Name.Contains('A') then
                    error('We do not want that account');
                if not TGC.Get(GL."Tax Group Code") then;

            end;
        }
    }
}

pageextension 50101 CPG extends "Customer Posting Groups"
{
    layout
    {
        addafter(Code)
        {
            field(ImportantAccount; Rec.ImportantAccount)
            {
                ApplicationArea = all;
            }
        }
    }
}