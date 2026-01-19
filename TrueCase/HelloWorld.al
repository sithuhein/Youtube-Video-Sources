// Welcome to your new AL extension.
// Remember that object names and IDs should be unique across all extensions.
// AL snippets start with t*, like tpageext - give them a try and happy coding!

namespace DefaultPublisher.TrueCase;

using Microsoft.Sales.Customer;

pageextension 50700 CustomerListExt extends "Customer List"
{
    trigger OnOpenPage();
    var
        x: Integer;
    begin
        x := 10;
        case true of
            x = 10:
                begin
                    message('10');
                    x := 11;
                end;
            x = 11:
                begin
                    message('12');
                    x := 13;
                end;
            else
                message('Else');
        end;
    end;
}