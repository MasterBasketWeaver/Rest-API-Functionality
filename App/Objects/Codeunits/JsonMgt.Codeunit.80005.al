codeunit 79991 "BAAPI Json Mgt."
{
    SingleInstance = true;

    procedure GetJsonValueAsText(var JsonObj: JsonObject; KeyName: Text): Text
    var
        T: JsonToken;
        V: JsonValue;
    begin
        if not JsonObj.Get(KeyName, T) then
            exit('');
        V := T.AsValue();
        if V.IsNull() or V.IsUndefined() then
            exit('');
        exit(V.AsText());
    end;

    procedure GetJsonValueAsDecimal(var JsonObj: JsonObject; KeyName: Text): Decimal
    var
        T: JsonToken;
        V: JsonValue;
    begin
        if not JsonObj.Get(KeyName, T) then
            exit(0);
        V := T.AsValue();
        if V.IsNull() or V.IsUndefined() then
            exit(0);
        if Format(V) = '""' then
            exit(0);
        exit(V.AsDecimal());
    end;

    procedure GetJsonValueAsInteger(var JsonObj: JsonObject; KeyName: Text): Integer
    var
        T: JsonToken;
        V: JsonValue;
    begin
        if not JsonObj.Get(KeyName, T) then
            exit(0);
        V := T.AsValue();
        if V.IsNull() or V.IsUndefined() then
            exit(0);
        if Format(V) = '""' then
            exit(0);
        exit(V.AsInteger());
    end;


    procedure GetJsonValueAsDateTime(var JsonObj: JsonObject; KeyName: Text): DateTime
    var
        T: JsonToken;
        V: JsonValue;
        Result: DateTime;
    begin
        if not JsonObj.Get(KeyName, T) then
            exit(0DT);
        V := T.AsValue();
        if V.IsNull() or V.IsUndefined() then
            exit(0DT);
        if Format(V) = '""' then
            exit(0DT);
        if not TryToConvrtJsonToDateTime(V, Result) then
            exit(0DT);
        exit(Result);
    end;

    [TryFunction]
    local procedure TryToConvrtJsonToDateTime(var V: JsonValue; var Result: DateTime)
    var
        s: Text;
    begin
        V.WriteTo(s);
        if Evaluate(Result, s.Replace('"', '')) then
            exit;
        Result := V.AsDateTime();
    end;


    procedure GetJsonValueAsBoolean(var JsonObj: JsonObject; KeyName: Text): Boolean
    var
        T: JsonToken;
        V: JsonValue;
    begin
        if not JsonObj.Get(KeyName, T) then
            exit(false);
        V := T.AsValue();
        if V.IsNull() or V.IsUndefined() then
            exit(false);
        exit(V.AsBoolean());
    end;
}