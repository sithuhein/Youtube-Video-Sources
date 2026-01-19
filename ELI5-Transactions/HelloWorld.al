// Welcome to your new AL extension.
// Remember that object names and IDs should be unique across all extensions.
// AL snippets start with t*, like tpageext - give them a try and happy coding!

namespace DefaultPublisher.ELI5Transactions;

using Microsoft.Sales.Customer;
using Microsoft.Sales.Document;

pageextension 50100 CustomerListExt extends "Customer List"
{
    trigger OnOpenPage();
    var
        i: INteger;
        SH: Record "Sales Header";
    begin
        Clear(SH);
        SH."Document Type" := SH."Document Type"::Quote;
        SH.Insert(true);
    end;

    trigger OnPageBackgroundTaskCompleted(TaskId: Integer; Results: Dictionary of [Text, Text])
}