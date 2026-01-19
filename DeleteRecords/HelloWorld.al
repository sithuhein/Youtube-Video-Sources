// Welcome to your new AL extension.
// Remember that object names and IDs should be unique across all extensions.
// AL snippets start with t*, like tpageext - give them a try and happy coding!

namespace DefaultPublisher.DeleteRecords;

using Microsoft.Sales.Customer;

pageextension 50100 CustomerListExt extends "Customer List"
{
    trigger OnOpenPage();
    var
        c: Record Customer;
        C2: Record Customer;
    begin
        c.setfilter("No.", 'C00060..');
        //c.Get('C00060');
        if c.findset(false) then
            repeat
                if C."No." = 'C00070' then
                    c.Delete();
            until c.Next() = 0;
    end;
}