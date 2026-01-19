page 50100 "AL Awaiting Deployment Hgd"
{
    PageType = StandardDialog;
    Caption = 'Awaiting Application Deployment';
    Editable = false;
    //DataCaptionFields = Description;
    DataCaptionExpression = CaptionTxt;
    SourceTable = "Extension Deployment Status";
    SourceTableTemporary = true;
    UsageCategory = None;

    layout
    {
        area(Content)
        {
            usercontrol(Logo; "AL HTMLHelper50 Hgd")
            {
                ApplicationArea = all;
                trigger ControlReady()
                begin
                    CurrPage.Logo.GetBaseUrlForResources('src/UI/Logo2.png');
                    CurrPage.Logo.StartTimer();
                    //ExtensionOp.GetAllExtensionDeploymentStatusEntries(Rec);
                end;

                trigger ReturnBaseURL(URL: Text)
                begin
                    CurrPage.Logo.Render('<div>' +
                                         '<img style="display: block;margin-left: 0px;margin-right: auto; height: 50px;" src="' + URL + '">' +
                                         '</div>');
                end;

                trigger TimerTic()
                var
                    ExtStatus: Record "Extension Deployment Status" temporary;
                    ExtensionOp: Codeunit "Extension Management";
                    TmpBlob: Codeunit "Temp Blob";
                    InS: InStream;
                    OutS: OutStream;
                    customDimensions: Dictionary of [Text, Text];
                    SwitchToForceMsg: Label 'It looks like you''re trying to publish deletions of tables or fields. In order to do this, you must set Publish Update Mode to Force and then republish your app.';
                    TwoAppsMsg: Label 'It looks like you''re trying to deploy a new app with same prefix as another app you have created. Please make sure that each app has a unique prefix defined in the setup.';
                    CircularReferenceLbl: Label 'You have created a circular reference. I can show you a video about this?';

                begin
                    if not IsNullGuid(Rec."Operation ID") then
                        ExtensionOp.RefreshStatus(Rec."Operation ID");
                    Rec.DeleteAll();
                    ExtensionOp.GetAllExtensionDeploymentStatusEntries(ExtStatus);
                    ExtStatus.SetFilter(Description, '''*' + AppName + '*''');
                    ExtStatus.SetCurrentKey("Started On");
                    if ExtStatus.FindLast() then begin
                        Rec := ExtStatus;
                        Rec.Insert();
                        clear(TmpBlob);
                        TmpBlob.CreateOutStream(OutS);
                        ExtensionOp.GetDeploymentDetailedStatusMessageAsStream(Rec."Operation ID", OutS);
                        TmpBlob.CreateInStream(InS);
                        InS.Read(DetailsTxt);
                        Elapsed := round(CurrentDateTime() - Rec."Started On", 1000);
                        if Rec.Description.IndexOf(' by ') > 1 then
                            CaptionTxt := copystr(Rec.Description, 1, Rec.Description.IndexOf(' by ') - 1)
                        else
                            CaptionTxt := Rec.Description;
                        CurrPage.Update(False);
                        If Rec.Status <> Rec.Status::InProgress then begin
                            CurrPage.Logo.StopTimer();
                            if Rec.Status = Rec.Status::Failed then
                                if DetailsTxt.Contains('Removing fields is not allowed') or
                                   DetailsTxt.Contains('Removing tables is not allowed') or
                                   DetailsTxt.Contains('Changing the data type') then
                                    message(SwitchToForceMsg);
                            if DetailsTxt.Contains('Field Transfers Mgt. ') then
                                message(TwoAppsMsg);
                            if DetailsTxt.Contains('CircularDependency') then
                                if confirm(CircularReferenceLbl) then
                                    Hyperlink('https://www.youtube.com/watch?v=4WfDkDn_Sxs');


                            clear(customDimensions);
                            customDimensions.add('RESULT', format(Rec.Status));
                            customDimensions.Add('DEPLOYMESSAGE', DetailsTxt);
                            LogMessage('DEPLOYRESULT',
                                        'Deployment Result',
                                        Verbosity::Normal,
                                        DataClassification::SystemMetadata,
                                        TelemetryScope::ExtensionPublisher,
                                        customDimensions);
                        end;
                    end;
                end;
            }
            group(AppInfo)
            {
                Caption = 'Deployment Information';
                field(Description; Rec.Description)
                {
                    ToolTip = 'The current task';
                    ApplicationArea = All;
                }
                field("Operation Type"; Rec."Operation Type")
                {
                    ToolTip = 'Operation Type';
                    ApplicationArea = All;
                }
                field("Started On"; Rec."Started On")
                {
                    ToolTip = 'Start time';
                    ApplicationArea = All;
                }
                field(ElapsedCtl; Elapsed)
                {
                    Caption = 'Elapsed';
                    ToolTip = 'Elapsed time sinze deployment start.';
                    ApplicationArea = all;
                }
                field(Status; Rec.Status)
                {
                    ToolTip = 'Current status of the deployment.';
                    ApplicationArea = All;
                }
            }
            group(Detailsgrp)
            {
                ShowCaption = false;
                field(Details; DetailsTxt)
                {
                    MultiLine = true;
                    ShowCaption = false;
                    ToolTip = 'Current deployment details.';
                    ApplicationArea = All;
                }
            }
        }
    }
    internal procedure SetAppName(Name: Text)
    begin
        AppName := Name;
    end;

    var
        AppName: Text;
        DetailsTxt: Text;
        Elapsed: Duration;
        CaptionTxt: Text;
}