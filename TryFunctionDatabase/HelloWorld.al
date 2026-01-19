// Welcome to your new AL extension.
// Remember that object names and IDs should be unique across all extensions.
// AL snippets start with t*, like tpageext - give them a try and happy coding!

namespace DefaultPublisher.TryFunctionDatabase;

using Microsoft.Sales.Customer;

pageextension 50100 CustomerListExt extends "Customer List"
{
    trigger OnOpenPage();
    begin
        if not test() then
            message('we could not divide by zero');
        message('Success!');
    end;

    [TryFunction]
    procedure test() // : Boolean
    var
        d, z : Decimal;
    begin
        Rec.FindFirst();
        Rec.Name := 'Test 102';
        Rec.Modify();
        d := 10 / z;
    end;
}

codeunit 50100 "Try"
{
    trigger OnRun()
    var
        d: decimal;
        z: Decimal;
    begin
        d := 10 / z;
    end;
}