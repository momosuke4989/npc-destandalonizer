unit userscript;

const
  FACEGEN_TEXTURE_PATH_FEMALE = 'textures\actors\character\female';
  FACEGEN_TEXTURE_PATH_MALE   = 'textures\actors\character\male';
  FACEGEN_TEXTURE_PATH_BLANK  = 'textures\actors\Character\Male\BlankDetailmap.dds';

var
  keepWNAMNPC, isCustomRace: boolean;

procedure ReplaceFaceGenTexturePath(faceMeshPath: string; isFemale: boolean);
var
  nif              : TwbNifFile;
  nifBlock         : TwbNifBlock;
  element          : TdfElement;
  lTextureList     : TList;
  slFileNameList   : TStringList;
  i, j             : Integer;
  defaultTexturePath,
  oldTexturePath, newTexturePath  : string;
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


    // デフォルトのテクスチャパスを取得する
    if isFemale then
      defaultTexturePath := FACEGEN_TEXTURE_PATH_FEMALE
    else
      defaultTexturePath := FACEGEN_TEXTURE_PATH_MALE;

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
        else begin
          newTexturePath := defaultTexturePath + '\' + ExtractFileName(oldTexturePath);
        end;
        if SameText(oldTexturePath, newTexturePath) then
          continue;

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
end;

function Initialize: integer;
begin
  // ユーザに色々尋ねる処理
  // NPCレコードからWorn Armorを削除する?
  if MessageDlg(
    'Do you want to maintain the NPC''s body shape?' + #13#10 +
    'Yes = Change the Worn Armor skin texture reference to default' + #13#10 +
    'No = Remove the Worn Armor element and use the race''s body shape and skin.', mtConfirmation, [mbYes, mbNo], 0
  ) = mrYes then
  keepWNAMNPC := true;

  // 対象のNPCはカスタム種族?
  // カスタム種族だった場合、デフォルトのSkinNakedはカスタム種族に対応していないのでWNAMの変更は難しい
  // テクスチャの参照先をデフォルト化する方法しか取れそうにない
  // 方針：Armatureリストを走査して、編集中のespファイル内に存在するArmatureがあればテクスチャ参照先をデフォルトに変更する
  // 外部espのArmatureを参照している場合はこのスクリプトの対象外とする。思わぬ編集をしてしまう事故が怖い。
  // NPCのWNAMのテクスチャ参照変更も同様の処理になりそうだ
  // 前提として獣人種族は非対応としたほうが無難か。そもそも需要ない気もする
  //1. 「編集中のespファイル内に存在する」の判定基準が甘い
  //masterofselfの判定導入する
  //2. TXST参照の差し替えが「効くケース」と「効かないケース」がある
  //ボディに関してはArmor Addonレコードにテクスチャセットの参照が設定されていたら「効く」はず
  //FaceGenは効かないのでnifを直接編集する必要がある
  //3. UVレイアウトの不一致リスク
  //スクリプト実行時の注意点として事前に周知し、ボディメッシュのタイプを一致させるのはユーザの責任とする
  //4. 性別・パーツ単位の網羅
  //男女、1st/3rd確認
  //5. 獣人除外の判定方法
  //3と同様、ユーザの責任で判断してもらう
  if MessageDlg(
    'Is the NPC''s race a custom race?' + #13#10 +
    'Races such as CoTR and UBE are also included in the custom races.' + #13#10
    , mtConfirmation, [mbYes, mbNo], 0
  ) = mrYes then
  isCustomRace := true;
  Result := 0;
end;

function Process(e: IInterface): integer;
var npcRecord, npcFlags: IInterface;
    isFemale: Boolean;
    pluginName, faceMeshPath, formID: string;

begin
  // NPCのレコードかどうか判定
  if Signature(e) <> 'NPC_' then begin
    AddMessage(GetElementEditValues(e, 'EDID') + ' is not NPC record.');
    Exit;
  end;

  npcRecord := e;
  pluginName := GetFileName(GetFile(npcRecord));
  formID := IntToHex64(GetElementNativeValues(npcRecord, 'Record Header\FormID') and  $FFFFFF, 8);
  faceMeshPath := Format('%smeshes\actors\character\FaceGenData\FaceGeom\%s\%s.nif', [DataPath, pluginName, formID]);
  npcFlags  := ElementByPath(npcRecord, 'ACBS - Configuration');

  // 男女の判定
  isFemale := GetElementEditValues(npcFlags, 'Flags\Female') = '1';
  if isFemale then begin
    AddMessage(GetElementEditValues(npcRecord, 'EDID') + ' is Female');
  end
  else begin
    AddMessage(GetElementEditValues(npcRecord, 'EDID') + ' is Male');
  end;

  // test code
  if keepWNAMNPC then begin
    AddMessage(GetElementEditValues(npcRecord, 'EDID') + ' will maintain the NPC''s body shape.');
  end
  else begin
    AddMessage(GetElementEditValues(npcRecord, 'EDID') + ' will remove the Worn Armor element and use the race''s body shape and skin.');
  end;

  if isCustomRace then begin
    AddMessage(GetElementEditValues(npcRecord, 'EDID') + ' is a custom race.');
  end;


  ReplaceFaceGenTexturePath(faceMeshPath, isFemale);



// Worn Armorの削除、初期化処理のオプションに従う

  Result := 0;
end;

function Finalize: integer;
begin
  Result := 0;
end;

end.
