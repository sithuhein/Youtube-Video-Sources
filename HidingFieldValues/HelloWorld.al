// Welcome to your new AL extension.
// Remember that object names and IDs should be unique across all extensions.
// AL snippets start with t*, like tpageext - give them a try and happy coding!

namespace DefaultPublisher.HidingFieldValues;

using Microsoft.Sales.Customer;

pageextension 50100 CustomerListExt extends "Customer Card"
{

    layout
    {
        addafter(Name)
        {
            field(youtube; Rec."Name 2")
            {
                ApplicationArea = all;
                MaskType = Concealed;
                //ExtendedDatatype = Masked;
                // trigger OnAssistEdit()
                // begin
                //     message('%1', Rec."Name 2");
                // end;
            }
        }
        modify(BalanceAsVendor)
        {
            MaskType = Concealed;
        }
    }
}