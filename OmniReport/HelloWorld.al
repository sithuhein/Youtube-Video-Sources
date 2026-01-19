report 57100 "OmniReport"
{
    Caption = 'Omni Report';
    //ProcessingOnly = true;
    ApplicationArea = all;

    dataset
    {
        dataitem(Records; Integer)
        {
            column(c1; format(Ref.Field(1).Value))
            { }
            column(c2; format(Ref.Field(2).Value))
            { }


            trigger OnPreDataItem()
            begin
                Records.setrange(Number, 1, RecCount);

            end;

            trigger OnAfterGetRecord()
            begin
                if Records.Number = 1 then
                    Ref.FindSet()
                else
                    Ref.Next();

                //message(format(Ref));
            end;

        }
    }

    requestpage
    {
        layout
        {
            area(Content)
            {
                field(TableNo; TableNo)
                {
                    trigger OnValidate()
                    begin
                        Ref.Open(TableNo);
                        RecCount := Ref.Count();
                    end;
                }
                field(ViewString; ViewString)
                {
                    trigger OnAssistEdit()
                    var
                        Builder: FilterPageBuilder;
                        v: Variant;
                    begin
                        Builder.PageCaption := 'Select ' + Ref.Name;
                        v := Ref;
                        Builder.AddRecord(Ref.Name, v);
                        if ViewString <> '' then
                            Builder.SetView(Ref.Name, ViewString);
                        if Builder.RunModal() then begin
                            ViewString := Builder.GetView(Ref.Name, true).Replace('VERSION(1) ', '');
                            Ref.SetView(ViewString);
                            RecCount := Ref.Count();
                        end;
                    end;
                }
                field(RecCountControl; RecCount)
                {
                    Caption = 'Selected Records';
                    Editable = false;
                }
            }
        }
    }

    // trigger OnPreReport()
    // begin
    //     if Ref.FindSet() then
    //         repeat
    //             // Do ya' thing!
    //             message('%1', Ref.Field(1).Value);
    //         until Ref.Next() = 0;
    // end;

    var
        Ref: RecordRef;
        RecCount: Integer;
        TableNo: Integer;
        ViewString: Text;
}