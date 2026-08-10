unit NPC_DeStandalonizer;

const
  FACEGEN_TEXTURE_PATH_FEMALE = 'textures\actors\character\female';
  FACEGEN_TEXTURE_PATH_MALE   = 'textures\actors\character\male';
  FACEGEN_TEXTURE_PATH_MSN    = 'textures\actors\character';
  FACEGEN_TEXTURE_PATH_BLANK  = 'textures\actors\Character\Male\BlankDetailmap.dds';

  NAKED_TORSO_NIF_PATH_MALE   = 'Actors\Character\Character Assets\MaleBody_1.NIF';
  NAKED_TORSO_NIF_PATH_FEMALE = 'Actors\Character\Character Assets\FemaleBody_1.NIF';
  NAKED_FEET_NIF_PATH_MALE    = 'Actors\Character\Character Assets\MaleFeet_1.NIF';
  NAKED_FEET_NIF_PATH_FEMALE  = 'Actors\Character\Character Assets\FemaleFeet_1.NIF';
  NAKED_HANDS_NIF_PATH_MALE   = 'Actors\Character\Character Assets\MaleHands_1.NIF';
  NAKED_HANDS_NIF_PATH_FEMALE = 'Actors\Character\Character Assets\FemaleHands_1.NIF';

  SKIN_BODY_TEXTURE_MALE_FORMID   = $0003EDE8;
  SKIN_BODY_TEXTURE_FEMALE_FORMID = $0003EDE7;
  SKIN_HAND_TEXTURE_MALE_FORMID   = $0003EDEA;
  SKIN_HAND_TEXTURE_FEMALE_FORMID = $0003EDE9;

var
  skyrimesm: IInterface;
  slBasicRaceList: TStringList;
  keepOriginalSkin: boolean;

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
  texturePathChanged : boolean;
begin
  if not FileExists(faceMeshPath) then begin
    AddMessage('Do not found FaceGen Nif file: ' + faceMeshPath);
    Exit;
  end;

  texturePathChanged := false;

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
      if raceName = 'Nord' then
        msnTexturePath := FACEGEN_TEXTURE_PATH_MSN + '\Female\Femalehead_msn.dds'
      else if raceName = 'WoodElf' then
        msnTexturePath := FACEGEN_TEXTURE_PATH_MSN + '\HighElfFemale\Femalehead_msn.dds'
      else
        msnTexturePath := FACEGEN_TEXTURE_PATH_MSN + '\' + raceName + 'Female\Femalehead_msn.dds';
    end
    else begin
      defaultTexturePath := FACEGEN_TEXTURE_PATH_MALE;
      if raceName = 'Nord' then
        msnTexturePath := FACEGEN_TEXTURE_PATH_MSN + '\Male\Malehead_msn.dds'
      else
        msnTexturePath := FACEGEN_TEXTURE_PATH_MSN + '\' + raceName + 'Male\Malehead_msn.dds';
    end;

    AddMessage('set default texture path: ' + defaultTexturePath);

    // NIFファイルのすべてのブロックを反復処理し、テクスチャを保持している要素を特定。
    for i := 0 to nif.BlocksCount - 1 do begin
        nifBlock := nif.Blocks[i];

        if nifBlock.BlockType = 'BSShaderTextureSet' then begin
            element := nifBlock.Elements['Textures'];
            for j := 0 to element.Count - 1 do
                lTextureList.Add(element[j]);
        end;
    end;

    //AddMessage(Format('Found %d elements.', [Elements.Count]));

    // テクスチャセットを持たない場合はスキップ
    if lTextureList.Count = 0 then begin
      AddMessage('  No BSShaderTextureSet found. Skipping.');
      Exit;
    end;

    // 収集したエレメント内のテクスチャパスを置換する
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
          AddMessage('This Texture path is already default:' + oldTexturePath);
          continue;
        end;

        element.EditValue := newTexturePath;
        AddMessage('Change FaceGen Skin Texture Path: ' + oldTexturePath + ' -> ' + newTexturePath);
        texturePathChanged := true;
      end;
    end;
    if texturePathChanged then begin
      if not FileExists(faceMeshPath + '.bak') then
        CopyFile(faceMeshPath, faceMeshPath + '.bak', false)
      else
        AddMessage('  Backup already exists, skipping: ' + faceMeshPath + '.bak');

      element.Root.SaveToFile(faceMeshPath);
    end;
  finally
    lTextureList.Free;
    slFileNameList.Free;
    nif.Free;
  end;
  AddMessage('ReplaceFaceGenTexturePath finished.');
end;

function IsBeastRace(raceRecord: IInterface): boolean;
var
  keywords, kwEntry, kw: IInterface;
  i: integer;
begin
  Result := false;
  keywords := ElementBySignature(raceRecord, 'KWDA');
  if not Assigned(keywords) then
    Exit;

  for i := 0 to ElementCount(keywords) - 1 do begin
    kwEntry := ElementByIndex(keywords, i);
    kw := LinksTo(kwEntry);
    if Assigned(kw) and SameText(EditorID(kw), 'IsBeastRace') then begin
      Result := true;
      Exit;
    end;
  end;
end;

function IsOfficialMaster(fileName: string): boolean;
begin
  Result :=
    SameText(fileName, 'Skyrim.esm') or
    SameText(fileName, 'Update.esm') or
    SameText(fileName, 'Dawnguard.esm') or
    SameText(fileName, 'HearthFires.esm') or
    SameText(fileName, 'Dragonborn.esm') or
    SameText(fileName, '_ResourcePack.esl') or
    SameText(fileName, 'ccBGSSSE001-Fish.esm') or
    SameText(fileName, 'ccBGSSSE025-AdvDSGS.esm')or
    SameText(fileName, 'ccBGSSSE037-Curios.esl') or
    SameText(fileName, 'ccQDRSSE001-SurvivalMode.esl');
end;

function HasBipedSlot(armaRecord: IInterface; slotLabel: string): boolean;
begin
  Result := GetElementEditValues(armaRecord,
    'BOD2 - Biped Body Template\First Person Flags\' + slotLabel) = '1';
end;

function ResolveDefaultAssetKey(armaRecord: IInterface): string;
begin
  if HasBipedSlot(armaRecord, '32 - Body') then
    Result := 'body'
  else if HasBipedSlot(armaRecord, '33 - Hands') then
    Result := 'hands'
  else if HasBipedSlot(armaRecord, '37 - Feet') then
    Result := 'feet'
  else
    Result := '';
end;

function GetDefaultModelPath(slotLabel: string; isFemale: boolean): string;
begin
  if slotLabel = 'body' then
  begin
    if isFemale then
      Result := NAKED_TORSO_NIF_PATH_FEMALE
    else
      Result := NAKED_TORSO_NIF_PATH_MALE;
  end
  else if slotLabel = 'feet' then
  begin
    if isFemale then
      Result := NAKED_FEET_NIF_PATH_FEMALE
    else
      Result := NAKED_FEET_NIF_PATH_MALE;
  end
  else if slotLabel = 'hands' then
  begin
    if isFemale then
      Result := NAKED_HANDS_NIF_PATH_FEMALE
    else
      Result := NAKED_HANDS_NIF_PATH_MALE;
  end;
end;

function GetDefaultTextureFormID(slotLabel: string; isFemale: boolean): Cardinal;
begin
  if slotLabel = 'body' then
  begin
    if isFemale then
      Result := SKIN_BODY_TEXTURE_FEMALE_FORMID
    else
      Result := SKIN_BODY_TEXTURE_MALE_FORMID;
  end
  else if slotLabel = 'feet' then
  begin
    if isFemale then
      Result := SKIN_BODY_TEXTURE_FEMALE_FORMID
    else
      Result := SKIN_BODY_TEXTURE_MALE_FORMID;
  end
  else if slotLabel = 'hands' then
  begin
    if isFemale then
      Result := SKIN_HAND_TEXTURE_FEMALE_FORMID
    else
      Result := SKIN_HAND_TEXTURE_MALE_FORMID;
  end;
end;

procedure UpdateArmaModel(armaRecord: IInterface; defaultNifPath: string; defaultSkinFormID: Cardinal; isFemale: boolean);
var
  modelElement, textureElement, textureSetRecord: IInterface;
  modelFieldName, textureFieldName: string;
  newValue: string;
begin
  // メッシュパスの変更
  if isFemale then
    modelFieldName := 'MOD3 - Model FileName' // Female World Model
  else
    modelFieldName := 'MOD2 - Model FileName'; // Male World Model
  modelElement := ElementBySignature(armaRecord, modelFieldName);

  AddMessage('  ' + 'Replace ' + modelFieldName + ' for ' + EditorID(armaRecord) + ': ' +
              GetElementEditValues(modelElement, modelFieldName) + ' -> ' + defaultNifPath);

  SetElementEditValues(modelElement, modelFieldName, defaultNifPath);

  // テクスチャセットの変更
  if not keepOriginalSkin then begin
    textureSetRecord := RecordByFormID(skyrimEsm, defaultSkinFormID, false);
    if not Assigned(textureSetRecord) then begin
      AddMessage('  [WARN] RecordByFormID failed for ' + IntToHex(defaultSkinFormID, 8));
      Exit;
    end;
    AddMessage('  Resolved texture record: ' + EditorID(textureSetRecord));

    if isFemale then
      textureFieldName := 'NAM1 - Female Skin texture'
    else
      textureFieldName := 'NAM0 - Male Skin texture';

    textureElement := ElementBySignature(armaRecord, textureFieldName);

    if not Assigned(textureElement) then begin
      AddMessage('  [WARN] textureElement not found: ' + textureFieldName);
      Exit;
    end;
      SetNativeValue(textureElement, FormID(textureSetRecord));
      AddMessage('  The texture set has been changed: ' + EditorID(textureSetRecord));
  end;

end;

function Initialize: integer;
begin
  skyrimesm := FileByIndex(0);

  slBasicRaceList := TStringList.Create;
  //slBasicRaceList.Add('KhajiitRace');
  //slBasicRaceList.Add('ArgonianRace');
  slBasicRaceList.Add('BretonRace');
  slBasicRaceList.Add('DarkElfRace');
  slBasicRaceList.Add('HighElfRace');
  slBasicRaceList.Add('ImperialRace');
  slBasicRaceList.Add('NordRace');
  slBasicRaceList.Add('OrcRace');
  slBasicRaceList.Add('RedguardRace');
  slBasicRaceList.Add('WoodElfRace');



  keepOriginalSkin := false;
  if MessageDlg(
    'Do you want to change the skin texture to the default?' + #13#10 +
    'Yes = Revert both the skin texture and body mesh to default.' + #13#10 +
    'No = Revert only the body mesh to default.' + #13#10
    , mtConfirmation, [mbYes, mbNo], 0
  ) = mrNo then
  keepOriginalSkin := true;
  Result := 0;
end;

function Process(e: IInterface): integer;
var npcRecord, npcFlags, npcRace, targetWNAM: IInterface;
    armatureList, armaEntry, armaRecord, armaMaster: IInterface;
    npcRaceRecord, targetWNAMRecord: IwbMainRecord;
    npcFlagsNative, defaultTextureFormID, i: Cardinal;
    isFemale, useTraitsFlag, isBasicHumanoidRace, isNativeAARecord: Boolean;
    pluginName, racePluginName, faceMeshPath, formID, raceName, slotLabel: string;
    defaultModelPath: string;

begin
  // NPCのレコードかどうか判定
  if Signature(e) <> 'NPC_' then begin
    AddMessage(GetElementEditValues(e, 'EDID') + ' is not NPC record.');
    Exit;
  end;

  isNativeAARecord := false;
  isBasicHumanoidRace := false;
  npcRecord := e;

  // 獣人種族は処理をスキップする
  npcRace := ElementByPath(npcRecord, 'RNAM');
  npcRaceRecord := MasterOrSelf(LinksTo(npcRace));
  if IsBeastRace(npcRaceRecord) then begin
    AddMessage(GetElementEditValues(npcRaceRecord, 'EDID') + ' has IsBeastRace Keyword. Processing will be skipped.');
    Exit;
  end;

  // UseTraitsフラグが立っている場合は処理をスキップする
  npcFlagsNative := GetElementNativeValues(ElementBySignature(npcRecord, 'ACBS'), 'Template Flags');
  if (npcFlagsNative and $01) <> 0 then begin
    AddMessage(GetElementEditValues(npcRecord, 'EDID') + ' uses the useTraits flag. Processing will be skipped.');
    Exit;
  end;

  // ユニーク種族の判定
  // ユニーク種族の判定は種族レコードがNPCレコードの所属プラグインと同じかどうかで判定する
  // FaceGen内のテクスチャパスの決定のために種族名を取得する。ユニーク種族の場合はノルドとして扱う。
  pluginName := GetFileName(GetFile(masterOrSelf(npcRecord)));
  racePluginName := GetFileName(GetFile(MasterOrSelf(npcRaceRecord)));
  if IsOfficialMaster(racePluginName) then begin
    for i := 0 to slBasicRaceList.Count - 1 do
    begin
      if SameText(GetElementEditValues(npcRaceRecord, 'EDID'), slBasicRaceList[i]) then begin
          AddMessage(GetElementEditValues(npcRaceRecord, 'EDID') + ' is a basic humanoid race.');
          isBasicHumanoidRace := true;
          raceName := Copy(slBasicRaceList[i], 1, Length(slBasicRaceList[i]) - 4);
          Break;
      end;
    end;
    if not isBasicHumanoidRace then begin
      AddMessage(GetElementEditValues(npcRaceRecord, 'EDID') + ' is not a basic humanoid race. Processing will be skipped.');
      Exit;
    end;
  end
  else begin
    if SameText(pluginName, racePluginName) then begin
      AddMessage(GetElementEditValues(npcRaceRecord, 'EDID') + 'is a unique race.');
      AddMessage('Foalback to Nord race for FaceGen texture path.');
      raceName := 'Nord';
    end
    else begin
      AddMessage(GetElementEditValues(npcRaceRecord, 'EDID') + 'is not a unique race. Processing will be skipped.');
      Exit;
    end;
  end;

  // 男女の判定
  npcFlags  := ElementByPath(npcRecord, 'ACBS');
  isFemale := GetElementEditValues(npcFlags, 'Flags\Female') = '1';
  if isFemale then begin
    AddMessage(GetElementEditValues(npcRecord, 'EDID') + ' is Female');
  end
  else begin
    AddMessage(GetElementEditValues(npcRecord, 'EDID') + ' is Male');
  end;

  if not keepOriginalSkin then begin
    // FaceGen メッシュファイルのパス生成
    formID := IntToHex64(GetElementNativeValues(npcRecord, 'Record Header\FormID') and  $FFFFFF, 8);
    faceMeshPath := Format('%smeshes\actors\character\FaceGenData\FaceGeom\%s\%s.nif', [DataPath, pluginName, formID]);

    // FaceGenのテクスチャパスを置換する
    ReplaceFaceGenTexturePath(faceMeshPath, raceName, isFemale);
  end;

  // ボディの処理
  // NPCレコードに設定されているWNAMがあればそれを対象にする
  // なければ、種族に設定されているWNAMレコードを対象にする。
  if Assigned(ElementByPath(npcRecord, 'WNAM')) then
    targetWNAM := ElementByPath(npcRecord, 'WNAM')
  else
    targetWNAM := ElementByPath(npcRaceRecord, 'WNAM');
  targetWNAMRecord := MasterOrSelf(LinksTo(targetWNAM));

  // WNAMレコードからさかのぼってArmorAddonを取得し、その参照先を変更する
  armatureList := ElementByName(targetWNAMRecord, 'Armature');
  if not Assigned(armatureList) then begin
    AddMessage(EditorID(targetWNAMRecord) + ' : No Armature list');
    Exit;
  end;

  for i := 0 to ElementCount(armatureList) - 1 do begin
    armaEntry := ElementByIndex(armatureList, i);
    armaRecord := LinksTo(armaEntry);

    armaMaster := MasterOrSelf(armaRecord);
    isNativeAARecord := Equals(GetFile(armaMaster), GetFile(npcRecord));

    if isNativeAARecord then begin
      slotLabel := ResolveDefaultAssetKey(armaRecord);
      AddMessage('Processing Armor Addon: ' + EditorID(armaRecord));
      if slotLabel = '' then
      begin
        AddMessage('This Armor Addon is not a body part: ' + EditorID(armaRecord));
        Continue;
      end
      else
      begin
        AddMessage('ArmorAddon slot:' + slotLabel);
        defaultModelPath := GetDefaultModelPath(slotLabel, isFemale);
        defaultTextureFormID := GetDefaultTextureFormID(slotLabel, isFemale);
        UpdateArmaModel(armaRecord, defaultModelPath, defaultTextureFormID, isFemale);
      end;
    end
    else begin
      AddMessage('This Armor Addon is not native. Processing will be skip.');
      Continue;
    end;
  end;

  Result := 0;
end;

function Finalize: integer;
begin
  Result := 0;
  slBasicRaceList.Free;
  AddMessage('Script execution completed.');
end;

end.
