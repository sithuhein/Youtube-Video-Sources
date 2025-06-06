codeunit 50102 "Print PDF Support"
{
    SingleInstance = true;

    var
        _InS: InStream;

    internal procedure PDFToPrint(var InS: InStream)
    begin
        _InS := InS;
    end;

    [EventSubscriber(ObjectType::Codeunit, Codeunit::ReportManagement, 'OnAfterDocumentReady', '', true, true)]
    local procedure OnAfterDocumentReady(ObjectId: Integer; var TargetStream: OutStream; var Success: Boolean)
    begin
        if ObjectId = Report::"Print PDF from SharePoint" then begin
            CopyStream(TargetStream, _InS);
            Success := true;
        end;
    end;

    procedure Print
}