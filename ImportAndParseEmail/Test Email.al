page 56400 "Test Email"
{
    PageType = List;
    ApplicationArea = all;
    SourceTable = "Email Details";

    layout
    {
        area(Content)
        {
            repeater(rep)
            {
                field(Type; Rec.Type)
                {
                    Width = 10;
                }
                field(HeaderKey; Rec.HeaderKey)
                {
                    Width = 10;
                }
                field(Value; Rec.Value)
                { }
            }
        }
    }
    actions
    {
        area(Processing)
        {
            action(Test)
            {
                Caption = 'Import';
                Promoted = true;
                PromotedCategory = Process;
                PromotedOnly = true;
                trigger OnAction()
                var
                    InS: InStream;
                begin
                    if UploadIntoStream('', InS) then
                        ImportAndParse(InS);
                end;
            }
            action(download)
            {
                Caption = 'Export Binary';
                Promoted = true;
                PromotedCategory = Process;
                PromotedOnly = true;
                trigger OnAction()
                var
                    InS: InStream;
                begin
                    Rec.CalcFields(Binary);
                    Rec.Binary.CreateInStream(InS);
                    DownloadFromStream(InS, '', '', '', Rec.HeaderKey);
                end;
            }
        }
    }
    trigger OnOpenPage()
    var

        BarcodeSymbology: Enum "Barcode Symbology";

        BarcodeFontProvider: Interface "Barcode Font Provider";

        Input: Text;
        Output: Text;
    begin
        // 1) Pick the field to encode

        Input := '12345678';



        // 2) Use built-in IDAutomation provider and Code 128 symbology

        BarcodeFontProvider := Enum::"Barcode Font Provider"::IDAutomation1D;

        BarcodeSymbology := Enum::"Barcode Symbology"::Code128;



        // 3) Validate and encode to barcode text for the font

        BarcodeFontProvider.ValidateInput(Input, BarcodeSymbology);

        Output := BarcodeFontProvider.EncodeFont(Input, BarcodeSymbology);
        message(output);
    end;

    local procedure ImportAndParse(InS: InStream)
    var
        Header: Record "Email Details";
        Base64: Codeunit "Base64 Convert";
        EmailTxt: Text;
        Lines: List of [Text];
        LF: Text[2];
        i: Integer;
        Line: Text;
        Tab: Text[1];
        HeaderKey: Text;
        HeaderValue: Text;
        Boundary: List of [Text];
        OutS: OutStream;
        InsidePart: Option Outside,Header,Data;
        Filename: Text;
        Encoding: Text;
        ContentType: Text;
        DataBuilder: TextBuilder;
        PartNo: Integer;
    begin
        LF[1] := 13;
        LF[2] := 10;
        Tab[1] := 9;
        InS.Read(EmailTxt);
        Lines := EmailTxt.Split(LF);
        //message('%1', Lines.Get(17));

        Header.DeleteAll();
        i := 0;
        repeat
            i += 1;
            Line := Lines.Get(i);
            if Line <> '' then begin
                if Line.StartsWith(' ') or Line.StartsWith(Tab) then begin
                    // This is an extension to the previous header line
                    Header.Value += ' ' + Line.Trim();
                    Header.Modify();
                end else begin
                    HeaderKey := Line.Substring(1, Line.IndexOf(':') - 1);
                    HeaderValue := Line.Substring(Line.IndexOf(':') + 1).Trim();
                    Header.Init();
                    Header.Type := Header.Type::Header;
                    Header.HeaderKey := HeaderKey;
                    Header.Value := HeaderValue;
                    Header.LineNo := i;
                    Header.Insert();
                end;
            end;
        until Line = '';

        Header.Setrange(HeaderKey, 'Content-Type');
        if Header.FindFirst() then
            boundary.add(GetHeaderDetail(Header.Value, 'boundary'));


        // If we have no boundary = raw text email
        if Boundary.Count = 0 then begin
            Header.Init();
            Header.Type := Header.Type::BodyPart;
            Header.HeaderKey := 'Body';
            Header.Value := '<Binary>';
            Header.Binary.CreateOutStream(OutS);
            repeat
                i += 1;
                Line := Lines.Get(i);
                OutS.WriteText(Line);
            until i = Lines.Count();
            Header.Insert();
        end else begin
            // Multipart
            repeat
                i += 1;
                Line := Lines.Get(i);

                case InsidePart of
                    InsidePart::Outside:
                        if Line = '--' + Boundary.get(Boundary.Count) then
                            InsidePart := InsidePart::Header;
                    InsidePart::Header:
                        begin
                            if (line = '') or (Line = '--' + Boundary.Get(Boundary.Count)) then begin
                                HeaderKey := '';
                                HeaderValue := '';
                            end else begin
                                HeaderKey := Line.Split(':').Get(1).Trim();
                                HeaderValue := Line.Split(':').Get(2).Trim();
                            end;
                            case HeaderKey.ToLower() of
                                'content-type':
                                    begin
                                        ContentType := HeaderValue.Split(';').Get(1).Trim();
                                        if ContentType.ToLower().StartsWith('multipart') then begin
                                            Boundary.Add(GetHeaderDetail(HeaderValue, 'boundary'));
                                        end;
                                    end;
                                'content-transfer-encoding':
                                    Encoding := HeaderValue.Split(':').Get(1).Trim();
                                'content-disposition':
                                    Filename := GetHeaderDetail(HeaderValue, 'filename');
                                '':
                                    begin
                                        InsidePart := InsidePart::Data;
                                        Clear(DataBuilder);
                                    end;
                            end;
                        end;
                    InsidePart::Data:
                        begin
                            if (Line = '--' + Boundary.Get(Boundary.Count)) or
                               (Line = '--' + Boundary.Get(Boundary.Count) + '--') then begin
                                // Done with data
                                InsidePart := InsidePart::Header;
                                Header.Init();
                                Header.Type := Header.Type::BodyPart;
                                if Filename <> '' then
                                    Header.HeaderKey := Filename
                                else
                                    Header.HeaderKey := ContentType;
                                Header.Value := '<Binary>';
                                Header.Binary.CreateOutStream(OutS);
                                if Encoding.ToLower() = 'base64' then
                                    Base64.FromBase64(DataBuilder.ToText().Trim(), OutS)
                                else
                                    OutS.WriteText(DataBuilder.ToText());
                                PartNo += 1;
                                Header.LineNo := PartNo;
                                Header.Insert();
                                if Boundary.Count > 1 then begin
                                    if (Line = '--' + Boundary.Get(Boundary.Count) + '--') then begin
                                        // Pop Boundary stack
                                        Boundary.RemoveAt(Boundary.Count);
                                        InsidePart := InsidePart::Outside;
                                    end;
                                end;
                                Filename := '';
                                ContentType := '';
                                Encoding := '';
                            end else
                                DataBuilder.AppendLine(Line);
                        end;
                end;
            until i = Lines.Count();
        end;

    end;

    local procedure GetHeaderDetail(var HeaderValue: Text; Detail: Text): Text
    var
        HeaderDetails: List of [Text];
        i: Integer;
        Part: Text;
    begin
        // Content-Type: multipart/alternative; boundary="=-yUudarCy00rzWbucCoj37g=="
        HeaderDetails := HeaderValue.Split(';');
        for i := 1 to HeaderDetails.Count() do begin
            Part := HeaderDetails.Get(i).Trim();
            if Part.ToLower().StartsWith(Detail + '=') then begin
                exit(Part.Substring(10).TrimStart('"').TrimEnd('"'));
            end;
        end;
    end;
}