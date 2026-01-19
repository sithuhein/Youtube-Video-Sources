// Welcome to your new AL extension.
// Remember that object names and IDs should be unique across all extensions.
// AL snippets start with t*, like tpageext - give them a try and happy coding!

namespace DefaultPublisher.TryFunctionsAreExpensive;

using Microsoft.Sales.Customer;

pageextension 58400 CustomerListExt extends "Customer List"
{
    trigger OnOpenPage();
    var
        Value: JsonValue;
        d: Date;
        i: Integer;
        Start: DateTime;
    begin
        Value.SetValue(today());

        Start := CurrentDateTime();
        for i := 1 to 10000 do begin
            if ValueAsDate(value, d) then;
        end;
        message('Elapsed %1', CurrentDateTime() - Start);
    end;

    local procedure ValueAsDate2(v: JsonValue; var OutDate: Date): Boolean
    begin
        exit(Evaluate(OutDate, v.AsText(), 9));
    end;

    [TryFunction]
    local procedure ValueAsDate(v: JsonValue; var OutDate: Date)
    begin
        OutDate := v.AsDate();
    end;
}