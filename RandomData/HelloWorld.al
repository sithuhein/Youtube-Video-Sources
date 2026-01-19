// Welcome to your new AL extension.
// Remember that object names and IDs should be unique across all extensions.
// AL snippets start with t*, like tpageext - give them a try and happy coding!

namespace DefaultPublisher.RandomData;

using Microsoft.Sales.Customer;
using Microsoft.CRM.BusinessRelation;
using Microsoft.Foundation.Address;
using System.RestClient;

pageextension 50120 CustomerListExt extends "Customer List"
{
    actions
    {
        addfirst(processing)
        {
            action(Import)
            {
                Caption = 'Create Customers';
                ApplicationArea = all;
                Promoted = true;
                PromotedCategory = Process;
                PromotedOnly = true;
                trigger OnAction()
                begin
                    Import();
                end;
            }
        }
    }
    procedure Import()
    var
        Rest: Codeunit "Rest Client";
        Country: Record "Country/Region";
        JSONTools: Codeunit JSONTools;
        Data: JsonObject;
        Results: JsonArray;
        T: JsonToken;
        Person: JsonObject;
        Customer: Record Customer;
        Name: JsonObject;
        Location: JsonObject;
        Street: JsonObject;
        Rel: Record "Contact Business Relation";
    begin
        //.DeleteAll();
        repeat
            Data := rest.GetAsJson('https://randomuser.me/api/?results=1000').AsObject();

            Results := JSONTools.GetArray(Data, 'results');

            foreach T in results do begin
                Person := T.AsObject();

                Customer.Init();
                Customer."No." := '';
                Customer.Insert(true);
                // Extract sub json structures
                Name := JSONTools.GetObj(Person, 'name');
                Location := JSONTools.GetObj(Person, 'location');
                Street := JSONTools.GetObj(Location, 'street');

                Customer.Validate(Name, JSONTools.GetText(Name, 'first') + ' ' + JSONTools.GetText(Name, 'last'));
                Customer.Validate(Address, JSONTools.GetText(Street, 'name') + ' ' + JSONTools.GetText(Street, 'number'));
                Customer.City := copystr(JSONTools.GetText(Location, 'city'), 1, MaxStrLen(Customer.City));
                Customer."Post Code" := JSONTools.GetText(Location, 'postcode');
                Customer.County := JSONTools.GetText(Location, 'state');
                //Customer."Country/Region Code"
                Customer."E-Mail" := JSONTools.GetText(Person, 'email');
                //Customer."Country/Region Code" := JSONTools.GetText(Person, 'country');
                Country.Setfilter(Name, '@*' + JSONTools.GetText(Location, 'country') + '*');
                if not Country.FindFirst() then begin
                    Country.Init();
                    Country.Code := copystr(JSONTools.GetText(Location, 'country'), 1, MaxStrLen(Country.Code));
                    Country.Name := copystr(JSONTools.GetText(Location, 'country'), 1, MaxStrLen(Country.Name));
                    Country.Insert();
                end else
                    Customer.Validate("Country/Region Code", Country.Code);
                Customer.Modify(false);
                commit();
            end;
        until false;
    end;
}