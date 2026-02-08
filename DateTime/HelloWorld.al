namespace DefaultPublisher.DateTime;

using Microsoft.Sales.Customer;
using System.Reflection;

pageextension 50100 CustomerListExt extends "Customer List"
{
    trigger OnOpenPage();
    var
        TypeHelper: Codeunit "Type Helper";
        Offset1, Offset2, Offset3 : Duration;
        DT: DateTime;
    begin
        TypeHelper.GetTimezoneOffset(Offset1, 'Pacific Standard Time');
        TypeHelper.GetUserTimezoneOffset(Offset2);
        TypeHelper.GetUserClientTypeOffset(Offset3);

        DT := CurrentDateTime();
        DT -= Offset1;
        Message('Offset''ed time = %1', DT);

        //message('%1\%2\%3', Offset1, Offset2, Offset3);

        Rec.FindFirst();
        Rec.TestDT := DT + Offset1;
        Rec.Modify();



        // Message('%1 vs %2', Rec.TestDT, TypeHelper.GetCurrUTCDateTimeISO8601());
    end;
}

tableextension 50100 "Customer" extends Customer
{
    fields
    {
        field(50100; TestDT; DateTime)
        {
            Caption = 'Test DateTime';
        }
    }
}