unit userscript;

procedure ReplaceFaceTintPath(faceMeshPath, faceTextureFullPath: string);
var
  nif              : TwbNifFile;
  nifBlock         : TwbNifBlock;
  element          : TdfElement;
  faceTintElement  : TdfElement;
  lTextureList     : TList;
  i, j, p          : Integer;
  key,
  oldFaceTintPath, newFaceTintPath  : string;
  findFaceTintPath : boolean;
begin
  try
    nif := TwbNifFile.Create;
    nif.LoadFromFile(faceMeshPath);

    findFaceTintPath := false;

    lTextureList := TList.Create;

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

      if Pos(LowerCase('FaceTint'), LowerCase(element.EditValue)) > 0 then begin
        findFaceTintPath := true;
        faceTintElement := element;
        oldFaceTintPath := element.EditValue;
        break;
      end;
    end;

    if not findFaceTintPath then begin
      AddMessage('FaceTint file path not found.');
      Exit;
    end;

    // 新しいFaceTintパスをnifファイルに設定
    key := 'textures\actors\character\FaceGenData\FaceTint\';
    p := Pos(LowerCase(key), LowerCase(faceTextureFullPath));
    newFaceTintPath := Copy(faceTextureFullPath, p, Length(faceTextureFullPath) - p + 1);
    faceTintElement.EditValue := newFaceTintPath;

    faceTintElement.Root.SaveToFile(faceMeshPath);
    AddMessage('Change FaceTint Path: ' + oldFaceTintPath + ' -> ' + newFaceTintPath);
  finally
    lTextureList.Free;
    nif.Free;
  end;
end;

function Initialize: integer;
begin
  Result := 0;
end;

function Process(e: IInterface): integer;
begin
  Result := 0;
end;

function Finalize: integer;
begin
  Result := 0;
end;

end.
