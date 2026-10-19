unit NPC_DeStandalonizer;

uses 'xEdit_mmskCommonLibrary\xEdit_mmskCommonLibrary';

const
  // Setting default values ​​for options
  // This constant defines the initial value for the checkbox option.
  // If you want it to be checked by default, change `false` to `true`.
  KEEP_ORIGINAL_SKIN_DEFAULT = 'false';
  KEEP_ORIGINAL_DETAIL_DEFAULT = 'false';

  FACEGEN_TEXTURE_PATH_BASE   = 'textures\actors\character';
  FACEGEN_TEXTURE_PATH_BLANK  = 'textures\actors\Character\Male\BlankDetailmap.dds';

  TEX_SLOT_DIFFUSE    = 0;
  TEX_SLOT_NORMAL     = 1;
  TEX_SLOT_SUBSURFACE = 2;
  TEX_SLOT_DETAIL     = 3;
  TEX_SLOT_SPECULAR   = 7;

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
  headType: string;
  keepOriginalSkin, keepOriginalDetail: boolean;

// フレームワーク選択（チェックボックス方式、排他制御あり）
// 複数選択された場合はエラーを表示して再選択させる
function SelectHeadType: string;
var
  opts, disableOpts: TStringList;
  vanillaSelected, cotrSelected, ubeSelected: Boolean;
  selectedCount: Integer;
begin
  Result := '';
  opts := TStringList.Create;
  disableOpts := TStringList.Create;
  try
    opts.Values['Vanilla and High Poly Head'] := 'False';
    opts.Values['COTR'] := 'False';
    //opts.Values['UBE'] := 'False';

    if not ShowCheckboxForm(opts, disableOpts, 'Select Head Type (choose only one)') then begin
      AddMessage('Selection was canceled.');
      Exit;
    end;

    vanillaSelected := GetBoolSLValue(opts.Values['Vanilla and High Poly Head']);
    cotrSelected        := GetBoolSLValue(opts.Values['COTR']);
    //ubeSelected     := GetBoolSLValue(opts.Values['UBE']);

    selectedCount := 0;
    if vanillaSelected then Inc(selectedCount);
    if cotrSelected then Inc(selectedCount);
    //if ubeSelected then Inc(selectedCount);
    // AddMessage('Selected Count: ' + IntToStr(selectedCount));

    // 複数選択された場合はエラーを表示して再選択させる
    if selectedCount > 1 then begin
      MessageDlg('Please select only one head type.', mtError, [mbOK], 0);
      Result := SelectHeadType; // 再選択
      Exit;
    end;

    // 何も選択されなかった場合もエラーを表示して再選択させる
    if selectedCount = 0 then begin
      MessageDlg('Please select a head type.', mtError, [mbOK], 0);
      Result := SelectHeadType; // 再選択
      Exit;
    end;

    if vanillaSelected then
      Result := 'Vanilla'
    else if cotrSelected then
      Result := 'COTR'
    else if ubeSelected then
      Result := 'UBE';

  finally
    opts.Free;
    disableOpts.Free;
  end;
end;

procedure ResolveFaceGenHeadTexturePaths_Vanilla(raceName: string; isFemale: boolean; var slFaceGenTexturePaths: TstringList);
var
  headKey, msnTexturePath: string;
begin
  if isFemale then begin
    headKey := '\female\femalehead';
    if raceName = 'Nord' then
      msnTexturePath := FACEGEN_TEXTURE_PATH_BASE + '\female\femalehead_msn.dds'
    else if raceName = 'WoodElf' then
      msnTexturePath := FACEGEN_TEXTURE_PATH_BASE + '\highelffemale\femalehead_msn.dds'
    else if raceName = 'Orc' then
      msnTexturePath := FACEGEN_TEXTURE_PATH_BASE + '\femaleorc\femaleheadorc_msn.dds'
    else
      msnTexturePath := FACEGEN_TEXTURE_PATH_BASE + '\' + raceName + 'female\femalehead_msn.dds';
  end
  else begin
    headKey := '\male\malehead';
    if raceName = 'Nord' then
      msnTexturePath := FACEGEN_TEXTURE_PATH_BASE + '\male\malehead_msn.dds'
    else if raceName = 'Orc' then
      msnTexturePath := FACEGEN_TEXTURE_PATH_BASE + '\orcmale\maleheadorc_msn.dds'
    else
      msnTexturePath := FACEGEN_TEXTURE_PATH_BASE + '\' + raceName + 'male\malehead_msn.dds';
  end;

  slFaceGenTexturePaths.Values['Diffuse']    := FACEGEN_TEXTURE_PATH_BASE + headKey + '.dds';
  slFaceGenTexturePaths.Values['Normal']     := msnTexturePath;
  slFaceGenTexturePaths.Values['Subsurface'] := FACEGEN_TEXTURE_PATH_BASE + headKey + '_sk.dds';
  slFaceGenTexturePaths.Values['Detail']     := FACEGEN_TEXTURE_PATH_BLANK;
  slFaceGenTexturePaths.Values['Specular']   := FACEGEN_TEXTURE_PATH_BASE + headKey + '_s.dds';

  AddMessage('Resolved FaceGen Texture Paths.');
end;

procedure ResolveFaceGenHeadTexturePaths_COtR(raceName: string; isFemale: boolean; var slFaceGenTexturePaths: TstringList);
var
  headKey, msnTexturePath: string;
begin
  if isFemale then begin
    headKey := 'Textures\!COR\Head\FemaleHead';
    if raceName = 'DarkElf' then
      msnTexturePath := 'Textures\!COR\Head\DarkElf\FemaleHead_msn.dds'
    else
      msnTexturePath := headKey + '_msn.dds'
  end
  else begin
    headKey := 'Textures\!COR_Male\Head\MaleHead';
    msnTexturePath := headKey + '_msn.dds'
  end;


  slFaceGenTexturePaths.Values['Diffuse']    := headKey + '.dds';
  slFaceGenTexturePaths.Values['Normal']     := msnTexturePath;
  slFaceGenTexturePaths.Values['Subsurface'] := headKey + '_sk.dds';
  slFaceGenTexturePaths.Values['Detail']     := FACEGEN_TEXTURE_PATH_BLANK;
  slFaceGenTexturePaths.Values['Specular']   := headKey + '_s.dds';

  AddMessage('Resolved FaceGen Texture Paths.');
end;

procedure ReplaceFaceGenTexturePath(faceMeshPath, raceName: string; isFemale: boolean);
var
  nif                   : TwbNifFile;
  nifBlock, shaderProp,
  textureSetBlock       : TwbNifBlock;
  element, texElement   : TdfElement;
  lTextureList          : TList;
  slFaceGenTexturePaths : TStringList;
  i, j                  : Integer;
  headKey, fileName,
  defaultTexturePath, oldTexturePath,
  newTexturePath, msnTexturePath  : string;
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
    slFaceGenTexturePaths := TStringList.Create;

    AddMessage('Processing FaceGen NIF: ' + faceMeshPath);

    // デフォルトのテクスチャパスを取得する
    if headType = 'Vanilla' then
      ResolveFaceGenHeadTexturePaths_Vanilla(raceName, isFemale, slFaceGenTexturePaths)
    else if headType = 'COTR' then
      ResolveFaceGenHeadTexturePaths_COtR(raceName, isFemale, slFaceGenTexturePaths);

    for i := 0 to nif.BlocksCount - 1 do begin
      nifBlock := nif.Blocks[i];
      // AddMessage('[' + IntToStr(i) + '] BlockType=' + nifBlock.BlockType + ' Name=' + nifBlock.EditValues['Name']);
      if nifBlock.IsNiObject('BSDynamicTriShape', True) then begin
        // AddMessage('  Passed IsNiObject check');
        if IsFaceGenHeadShape(nifBlock) then begin
          // AddMessage('  Passed IsFaceGenHeadShape check.');
          shaderProp := nifBlock.PropertyByType('BSLightingShaderProperty', True);
          textureSetBlock := TwbNifBlock(shaderProp.Elements['Texture Set'].LinksTo);
          if Assigned(textureSetBlock) then begin
            element := textureSetBlock.Elements['Textures'];
            for j := 0 to element.Count - 1 do
              lTextureList.Add(element[j]);
          end;
        end;
      end;
    end;

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

      element := textureSetBlock.Elements['Textures'];

        texElement := TdfElement(element[i]);
        if texElement.EditValue = '' then
          continue;

        oldTexturePath := texElement.EditValue;
        fileName := ExtractFileName(oldTexturePath);

        case i of
          TEX_SLOT_DIFFUSE:
            newTexturePath := slFaceGenTexturePaths.Values['Diffuse'];
          TEX_SLOT_NORMAL:
            newTexturePath := slFaceGenTexturePaths.Values['Normal'];
          TEX_SLOT_SUBSURFACE:
            newTexturePath := slFaceGenTexturePaths.Values['Subsurface'];
          TEX_SLOT_DETAIL:
            newTexturePath := slFaceGenTexturePaths.Values['Detail'];
          TEX_SLOT_SPECULAR:
            newTexturePath := slFaceGenTexturePaths.Values['Specular'];
          else
            continue;
        end;

        if SameText(oldTexturePath, newTexturePath) then begin
          AddMessage('This Texture path is already default: ' + oldTexturePath);
          continue;
        end;

        if i = TEX_SLOT_DETAIL then begin
          if keepOriginalDetail then begin
            AddMessage('Keep original FaceGen Detail Texture: ' + oldTexturePath);
            continue;
          end;
        end;
        texElement.EditValue := newTexturePath;
        AddMessage('Change FaceGen Skin Texture Path: ' + oldTexturePath + ' -> ' + newTexturePath);
        texturePathChanged := true;
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
    slFaceGenTexturePaths.Free;
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
  Result :=
    (GetElementEditValues(armaRecord, 'BOD2 - Biped Body Template\First Person Flags\' + slotLabel) = '1') or
    (GetElementEditValues(armaRecord, 'BODT - Body Template\First Person Flags\' + slotLabel) = '1');
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

function IsFaceGenHeadShape(shapeBlock: TwbNifBlock): boolean;
var
  shaderProp: TwbNifBlock;
begin
  Result := false;
  shaderProp := shapeBlock.PropertyByType('BSLightingShaderProperty', True);
  if not Assigned(shaderProp) then
    Exit;

  Result := shaderProp.NativeValues['Shader Flags 1\Facegen_Detail_Map'];
end;

function Initialize: integer;
var
  slOpts, slDisableOpts: TStringList;
  checkBoxCaption: string;
  i: Integer;
begin
  Result := 0;
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
  keepOriginalDetail := false;

  headType := SelectHeadType;
  AddMessage('  selected head type: ' + headType);

  slOpts                := TStringList.Create;
  slDisableOpts         := TStringList.Create;

  checkBoxCaption             := 'Choose De-Standalonizer Option';

  // 各オプションの設定
  try

    slOpts.Values['Keep original skin texture'] := KEEP_ORIGINAL_SKIN_DEFAULT;
    slOpts.Values['Keep original FaceGen detail texture'] := KEEP_ORIGINAL_DETAIL_DEFAULT;

    if ShowCheckboxForm(slOpts, slDisableOpts, checkBoxCaption) then
    begin
      AddMessage('You selected:');
      for i := 0 to slOpts.Count - 1 do
        AddMessage('  ' + slOpts.Names[i] + ' - ' + slOpts.ValueFromIndex[i]);
    end
    else begin
      AddMessage('Selection was canceled.');
      Result := ISOLATE_ABORT;
      Exit;
    end;

    // オプションの選択状況をグローバル変数に反映する
    keepOriginalSkin := GetBoolSLValue(slOpts.Values['Keep original skin texture']);
    keepOriginalDetail := GetBoolSLValue(slOpts.Values['Keep original FaceGen detail texture']);

  finally
    slOpts.Free;
    slDisableOpts.Free;
  end;

end;

function Process(e: IInterface): integer;
var npcRecord, npcRace, targetWNAM: IInterface;
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
  isFemale := IsNPCFemale(npcRecord);
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
      AddMessage(EditorID(armaRecord) + ' is not native. Processing will be skip.');
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
