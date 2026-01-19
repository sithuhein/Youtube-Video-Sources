pageextension 50100 "xx" extends "Customer List"
{
    actions
    {
        addfirst(processing)
        {
            action(test)
            {
                Caption = 'Test';
                ApplicationArea = all;
                trigger OnAction()
                var
                    Window: Dialog;
                begin
                    WIndow.Open('Test #1#########################');
                    Window.Update(1, 'Test');
                    Page.Run(Page::"AL Awaiting Deployment Hgd");
                end;
            }
        }
    }
}