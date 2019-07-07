clear;
clc;
load mangnhandangchuso.mat
load label.mat

%% Xu li video
vidFileName = '20190412_095738.mp4'; % Ten file video
vidOrigin = VideoReader(vidFileName);
vidOrigin.CurrentTime = 56;

while (vidOrigin.CurrentTime < vidOrigin.Duration)
    Frm = readFrame(vidOrigin); % Lay tung frame anh trong video

    % Nhan dang bien ten duong
    frmBlue = colormask(Frm, [200 250], [40 100], [40 100]); %Nhan dang mau xanh
    % Ham color mask xet cac diem anh co gia tri mau HSV ([hue], [saturation], [value]) len gia tri 1, con lai bang 0
    [fB, fL] = bwboundaries(frmBlue, 4, 'noholes'); % Tim cac hinh trong anh bo qua cac lo (holes)
    % https://www.mathworks.com/help/images/ref/bwboundaries.html
    frmStats = regionprops(fL, 'Area', 'Orientation', 'BoundingBox'); % Tim cac thong so cua cac hinh 4-connector
    % https://www.mathworks.com/help/images/ref/regionprops.html

    for i = 1:1:size(fB, 1)
        if (frmStats(i).BoundingBox(3) / frmStats(i).BoundingBox(4) > 1) && (frmStats(i).BoundingBox(3) / frmStats(i).BoundingBox(4) < 2) && (frmStats(i).Area > 5000) && (frmStats(i).Orientation < 0)
            % BoundingBox: [xmin ymin (xmax - xmin) (ymax - ymin)] hinh chu nhat bao ben ngoai    
            
            % Xoay + cat hinh lai
            chrCrop = imcrop(Frm, frmStats(i).BoundingBox);
            chrRotate = imrotate(chrCrop, -frmStats(i).Orientation*0.4, 'loose');
            bCrop = size(chrCrop, 2)*sin(-frmStats(i).Orientation*0.4/180*pi);
            aCrop = sqrt(abs(size(chrCrop, 1)^2 - (size(chrRotate, 1) - bCrop)^2));
            asizeCrop = size(chrRotate, 2) - 2*aCrop;
            bsizeCrop = size(chrRotate, 1) - 2*bCrop;
            chrCrop2 = imcrop(chrRotate, [aCrop bCrop asizeCrop bsizeCrop]);
            chrCrop2 = imresize(chrCrop2, [120 140]);
            
            
            % Nhan dang chu cai tren bien
            chrfrmInvert = imcomplement(rgb2gray(chrCrop2));
            chrfrmBi = imbinarize(chrfrmInvert,'adaptive','ForegroundPolarity','dark','Sensitivity',0.5);
            chrfrmDila = imdilate(~chrfrmBi, strel('line', 2, 90)); %Lam day chieu doc
            [chrB, chrL] = bwboundaries(chrfrmDila, 4, 'noholes'); %Tim duong bao cac chu cai
            chrStats = regionprops(chrL, 'Area', 'BoundingBox');
            
            refRow = 64;
            refCol = 32;
            txt = '';
            chrNum = 0;
            
            if size(chrB, 1) > 0
                chrArray{1} = chrStats(1);
                for j = 1:1:size(chrB, 1)
                    if (chrStats(j).BoundingBox(4) / chrStats(j).BoundingBox(3) > 1) && (chrStats(j).BoundingBox(4) / chrStats(j).BoundingBox(3) < 4.5)  && (chrStats(j).Area > 100)
                        % Chon ra nhung hinh co chieu doc > chieu ngang va ti le nho hon 4.5
                        chrNum = chrNum + 1;
                        chrArray{chrNum} = chrStats(j);
                    end
                end
            end
            
            if (chrNum > 0)
                rowArray = zeros(1, chrNum);
                colArray = zeros(1, chrNum);
                for j = 1:1:chrNum
                    rowArray(j) = chrArray{j}.BoundingBox(2) + chrArray{j}.BoundingBox(4)/2;
                    colArray(j) = chrArray{j}.BoundingBox(1) + chrArray{j}.BoundingBox(3)/2;
                end

                for j = 1:1:(chrNum - 1)
                    for k = j:1:chrNum
                        if rowArray(j) > rowArray(k)
                            [rowArray(j), rowArray(k)] = swap(rowArray(j), rowArray(k));
                            [colArray(j), colArray(k)] = swap(colArray(j), colArray(k));
                            [chrArray{j}, chrArray{k}] = swap(chrArray{j}, chrArray{k});
                        end
                    end
                end

                rowAvr = rowArray(1);
                newRow = 1;
                for j = 2:1:chrNum
                    if abs(rowArray(j) - rowAvr) < 10
                        rowAvr = (rowAvr*(j - newRow) + rowArray(j))/(j - newRow + 1);
                        for k = newRow:1:j
                            rowArray(k) = rowAvr;
                        end
                    else
                        rowAvr = rowArray(j);
                        newRow = j;
                    end
                end

                for j = 1:1:(chrNum - 1)
                    for k = j:1:chrNum
                        if (rowArray(j) == rowArray(k)) && (colArray(j) > colArray(k))
                            [colArray(j), colArray(k)] = swap(colArray(j), colArray(k));
                            [chrArray{j}, chrArray{k}] = swap(chrArray{j}, chrArray{k});
                        end
                    end
                end

                strtxt = '';
                for j = 1:1:chrNum
                    chr = rgb2gray(imcrop(chrCrop2, chrArray{j}.BoundingBox));       
                    chr = imresize(chr, [refRow refCol]);
                    chrHog = extractHOGFeatures(chr)';
                    % trich dac trung HOG nhan dien chu
                     y = sim(Net ,chrHog);
                    [ymax ,ind] = max(y);

                    if ymax < 0.7
                      ind = 32;
                    end

                    %Hien ten duong
                    st = sprintf('%s', Label(ind));
                    
                    strtxt = strcat(strtxt, st);

                end

                txt = '';
                rowtxt = 1;
                coltxt = 1;
                txt(rowtxt, coltxt) = strtxt(1);

                for j = 2:1:(chrNum)
                    if rowArray(j) == rowArray(j - 1)
                        coltxt = coltxt + 1;
                        if (chrArray{j}.BoundingBox(1) - chrArray{j - 1}.BoundingBox(1) - chrArray{j - 1}.BoundingBox(3)) > 5
                            coltxt = coltxt + 1;
                        end
                        txt(rowtxt, coltxt) = strtxt(j);
                    else
                        coltxt = coltxt + 2;
                        txt(rowtxt, coltxt) = strtxt(j);
                    end
                end
                Frm = insertShape(Frm, 'Rectangle', frmStats(i).BoundingBox, 'Color', 'red', 'lineWidth', 5); % Hinh chu nhat detect bien bao           
                Frm = insertText(Frm, frmStats(i).BoundingBox(1:2), txt, 'AnchorPoint', 'RightTop', 'FontSize', 30);
            end
        end
    end

    imshow(Frm);
end

