// Welcome to your new AL extension.
// Remember that object names and IDs should be unique across all extensions.
// AL snippets start with t*, like tpageext - give them a try and happy coding!

namespace DefaultPublisher.SlowToTryFunction;

using Microsoft.Sales.Customer;

pageextension 58700 CustomerListExt extends "Customer List"
{
    trigger OnOpenPage();
    var
        i: Integer;
        V: JsonValue;
        T: JsonToken;
        S1: DateTime;
        D: Date;
    begin
        V.Setvalue(5.7);
        message('%1', evaluate(D, V.ASText()));
        message('%1', evaluate(D, V.ASText(), 9));
        V.SetValue('ABC');
        T := V.AsToken();
        S1 := CurrentDateTime();
        for i := 1 to 10000 do begin
            if TryIsDate(T, D) then;
        end;
        Message('Try = %1', CurrentDateTime() - S1);

        S1 := CurrentDateTime();
        for i := 1 to 10000 do begin
            if IsDate(T, D) then;
        end;
        Message('Evaluate = %1', CurrentDateTime() - S1);
    end;

    [TryFunction]
    local procedure TryIsDate(CellToken: JsonToken; var OutDate: Date)
    begin
        OutDate := CellToken.AsValue().AsDate();
    end;

    local procedure IsDate(CellToken: JsonToken; var OutDate: Date): Boolean
    begin
        if Evaluate(OutDate, CellToken.AsValue().AsText(), 9) then
            exit(true);
    end;
}