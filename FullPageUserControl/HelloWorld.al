page 50112 "Test"
{
    PageType = Card;
    SourceTable = Customer;
    Editable = false;
    UsageCategory = None;
    ApplicationArea = all;
    //DataCaptionExpression = Rec.Name;
    layout
    {
        area(Content)
        {
            usercontrol(test; fullpagetest)
            {
            }
        }
    }
    actions
    {
        area(Processing)
        {
            action(Test2)
            {
                Caption = 'Test';
                trigger OnAction()
                begin
                    message('hello');
                end;
            }
        }
    }
}
