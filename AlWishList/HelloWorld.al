pageextension 50100 CustomerListExt extends "Customer List"
{
    trigger OnOpenPage();
    var
        HttpContent: HttpContent;
        JO: JsonObject;
        JA: JsonArray;
        T: JsonToken;
        Txt: Text;
        C: Code[100];
        Ref: RecordRef;
    begin
        Txt := '12345678';

        Rec.TransferFields();


        message(Txt.Substring(-3));
    end;
}