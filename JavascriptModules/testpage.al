page 50100 "Deep Chat Test"
{
    PageType = UserControlHost;
    Caption = 'Deep Chat Demo';
    ApplicationArea = all;

    layout
    {
        area(Content)
        {
            usercontrol(deepchat; DeepChat)
            {
                trigger ControlReady()
                begin
                    CurrPage.deepchat.Init();
                end;
            }
        }
    }
}