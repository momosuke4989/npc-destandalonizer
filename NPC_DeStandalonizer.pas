unit NPC_DeStandalonizer;

const
  FACEGEN_TEXTURE_PATH_FEMALE = 'textures\actors\character\female';
  FACEGEN_TEXTURE_PATH_MALE   = 'textures\actors\character\male';
  FACEGEN_TEXTURE_PATH_MSN    = 'textures\actors\character';
  FACEGEN_TEXTURE_PATH_BLANK  = 'textures\actors\Character\Male\BlankDetailmap.dds';

var
 slBasicRaceList: TStringList;
 isUniqueRace: boolean;

procedure ReplaceFaceGenTexturePath(faceMeshPath, raceName: string; isFemale: boolean);
var
  nif              : TwbNifFile;
  nifBlock         : TwbNifBlock;
  element          : TdfElement;
  lTextureList     : TList;
  slFileNameList   : TStringList;
  i, j             : Integer;
  defaultTexturePath,
  oldTexturePath, newTexturePath, msnTexturePath  : string;
begin
  try
    nif := TwbNifFile.Create;
    nif.LoadFromFile(faceMeshPath);

    lTextureList := TList.Create;
    slFileNameList := TStringList.Create;

    if isFemale then begin
      slFileNameList.add('femalehead.dds');
      slFileNameList.add('femalehead_msn.dds');
      slFileNameList.add('femalehead_sk.dds');
      slFileNameList.add('femalehead_s.dds');
    end
    else begin
      slFileNameList.add('malehead.dds');
      slFileNameList.add('malehead_msn.dds');
      slFileNameList.add('malehead_sk.dds');
      slFileNameList.add('malehead_s.dds');
    end;
    slFileNameList.add('BlankDetailmap.dds');

    AddMessage('Processing FaceGen NIF: ' + faceMeshPath);

    // デフォルトのテクスチャパスを取得する
    if isFemale then begin
      defaultTexturePath := FACEGEN_TEXTURE_PATH_FEMALE;
      if (raceName = 'Nord') or isUniqueRace = true then
        msnTexturePath := FACEGEN_TEXTURE_PATH_MSN + '\Female\Femalehead_msn.dds'
      else if raceName = 'WoodElf' then
        msnTexturePath := FACEGEN_TEXTURE_PATH_MSN + '\HighElfFemale\Femalehead_msn.dds'
      else
        msnTexturePath := FACEGEN_TEXTURE_PATH_MSN + '\' + raceName + 'Female\Femalehead_msn.dds';
    end
    else begin
      defaultTexturePath := FACEGEN_TEXTURE_PATH_MALE;
      if (raceName = 'Nord') or isUniqueRace =true then
        msnTexturePath := FACEGEN_TEXTURE_PATH_MSN + '\Male\Malehead_msn.dds'
      else
        msnTexturePath := FACEGEN_TEXTURE_PATH_MSN + '\' + raceName + 'Male\Malehead_msn.dds';
    end;

    AddMessage('set default texture path: ' + defaultTexturePath);

    // Iterate over all blocks in a nif file and locate elements holding textures.
    for i := 0 to nif.BlocksCount - 1 do begin
        nifBlock := nif.Blocks[i];

        if nifBlock.BlockType = 'BSShaderTextureSet' then begin
            element := nifBlock.Elements['Textures'];
            for j := 0 to element.Count - 1 do
                lTextureList.Add(element[j]);
        end;
    end;

    //AddMessage(Format('Found %d elements.', [Elements.Count]));

    // Skip to the next file If nothing was found.
    if lTextureList.Count = 0 then
      Exit;

    // Do text replacement in collected elements.
    for i := 0 to lTextureList.Count - 1 do begin
      if not Assigned(lTextureList[i]) then
        continue;

      element := TdfElement(lTextureList[i]);

      if element.EditValue = '' then
        continue;

      if slFileNameList.IndexOf(ExtractFileName(element.EditValue)) >= 0 then begin
        oldTexturePath := element.EditValue;
        if SameText(ExtractFileName(element.EditValue), ExtractFileName(FACEGEN_TEXTURE_PATH_BLANK)) then begin
          newTexturePath := FACEGEN_TEXTURE_PATH_BLANK;
        end
        else if SameText(ExtractFileName(element.EditValue), ExtractFileName(msnTexturePath)) then begin
          newTexturePath := msnTexturePath;
        end
        else begin
          newTexturePath := defaultTexturePath + '\' + ExtractFileName(oldTexturePath);
        end;

        if SameText(oldTexturePath, newTexturePath) then
        begin
          AddMessage('This Texture path is already dfault:' + oldTexturePath);
          continue;
        end;

        element.EditValue := newTexturePath;
        AddMessage('Change FaceGen Skin Texture Path: ' + oldTexturePath + ' -> ' + newTexturePath);
        element.Root.SaveToFile(faceMeshPath);
      end;

    end;
  finally
    lTextureList.Free;
    slFileNameList.Free;
    nif.Free;
  end;
  AddMessage('ReplaceFaceGenTexturePath finished.');
end;

function Initialize: integer;
begin
  slBasicRaceList := TStringList.Create;
  slBasicRaceList.Add('KhajiitRace');
  slBasicRaceList.Add('ArgonianRace');
  slBasicRaceList.Add('BretonRace');
  slBasicRaceList.Add('DarkElfRace');
  slBasicRaceList.Add('HighElfRace');
  slBasicRaceList.Add('ImperialRace');
  slBasicRaceList.Add('NordRace');
  slBasicRaceList.Add('OrcRace');
  slBasicRaceList.Add('RedguardRace');
  slBasicRaceList.Add('WoodElfRace');

  isUniqueRace := false;
  if MessageDlg(
    'Is the NPC''s race a unique race?' + #13#10 +
    'Select "Yes" if it is a race used exclusively by that NPC-meaning it is not a race like CoTR or UBE.' + #13#10
    , mtConfirmation, [mbYes, mbNo], 0
  ) = mrYes then
  isUniqueRace := true;
  Result := 0;
end;

function Process(e: IInterface): integer;
var npcRecord, npcFlags, npcRace, raceWNAM, armorAddonRef: IInterface;
    npcRaceRecord, raceWNAMRecord: IwbMainRecord;
    npcFlagsNative, i: Cardinal;
    isFemale, useTraitsFlag, isHumanoidRace: Boolean;
    pluginName, faceMeshPath, formID, raceName: string;

begin
  // NPCのレコードかどうか判定
  if Signature(e) <> 'NPC_' then begin
    AddMessage(GetElementEditValues(e, 'EDID') + ' is not NPC record.');
    Exit;
  end;

  npcRecord := e;
  npcRace := ElementByPath(npcRecord, 'RNAM');
  npcRaceRecord := MasterOrSelf(LinksTo(npcRace));
  npcFlagsNative := GetElementNativeValues(ElementBySignature(npcRecord, 'ACBS'), 'Template Flags');

  // UseTraitsフラグが立っている場合は処理をスキップする
  if (npcFlagsNative and $01) <> 0 then begin
    AddMessage(GetElementEditValues(npcRecord, 'EDID') + ' uses the useTraits flag. Processing will be skipped.');
    Exit;
  end;

  // ユニーク種族でない場合は、基本種族かどうかを判定し、獣人種族または基本種族でない場合は処理をスキップする
  if not isUniqueRace then begin
    // Check if the NPC's race is a basic race
    for i := 0 to slBasicRaceList.Count - 1 do
    begin
      if SameText(GetElementEditValues(npcRaceRecord, 'EDID'), slBasicRaceList[i]) then
      begin
        if SameText(slBasicRaceList[i], 'KhajiitRace') or SameText(slBasicRaceList[i], 'ArgonianRace') then
        begin
          AddMessage(GetElementEditValues(npcRaceRecord, 'EDID') + ' is a beast race. Processing will be skipped.');
          Exit;
        end
        else begin
          AddMessage(GetElementEditValues(npcRaceRecord, 'EDID') + ' is a basic humanoid race.');
          isHumanoidRace := true;
          raceName := Copy(slBasicRaceList[i], 1, Length(slBasicRaceList[i]) - 4);
          Break;
        end;
      end;
    end;
    if not isHumanoidRace then begin
      AddMessage(GetElementEditValues(npcRaceRecord, 'EDID') + ' is not a basic humanoid race. Processing will be skipped.');
      Exit;
    end;
  end;

  pluginName := GetFileName(GetFile(masterOrSelf(npcRecord)));
  formID := IntToHex64(GetElementNativeValues(npcRecord, 'Record Header\FormID') and  $FFFFFF, 8);
  faceMeshPath := Format('%smeshes\actors\character\FaceGenData\FaceGeom\%s\%s.nif', [DataPath, pluginName, formID]);
  npcFlags  := ElementByPath(npcRecord, 'ACBS');

  // 男女の判定
  isFemale := GetElementEditValues(npcFlags, 'Flags\Female') = '1';
  if isFemale then begin
    AddMessage(GetElementEditValues(npcRecord, 'EDID') + ' is Female');
  end
  else begin
    AddMessage(GetElementEditValues(npcRecord, 'EDID') + ' is Male');
  end;

  // FaceGenのテクスチャパスを置換する
  ReplaceFaceGenTexturePath(faceMeshPath, raceName, isFemale);

  // ボディの処理
  // NPCレコードのWNAMを削除
  RemoveElement(npcRecord, 'WNAM');
  AddMessage('NPC WNAM fieald was Removed');
{
  // ユニーク種族の場合は、種族に設定されたWNAMからさかのぼってArmorAddonを取得し、その参照先を変更する
  if isUniqueRace then begin
    // ユニーク種族のWNAMを取得
    raceWNAM := ElementByPath(npcRaceRecord, 'WNAM');
    if not Assigned(raceWNAM) then begin
      AddMessage(GetElementEditValues(npcRaceRecord, 'EDID') + ' does not have a WNAM. Processing will be skipped.');
      Exit;
    end;
    raceWNAMRecord := MasterOrSelf(LinksTo(raceWNAM));

    // raceWNAMRecordのArmotureリストから、同一esp内で定義されているArmorAddonを取得

  end;
}
  Result := 0;
end;

function Finalize: integer;
begin
  Result := 0;
  slBasicRaceList.Free;
end;

end.
