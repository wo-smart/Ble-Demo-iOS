//
//  TTTSelectImageFun.m
//  TianTianTui
//
//  Created by 黄博 on 2017/2/27.
//  Copyright © 2017年 TianTianTui. All rights reserved.
//

#import "TTTSelectImageFun.h"
#import "TTTSysytemAuthority.h"
#import "TZImagePickerController.h"
#import "TZImageManager.h"
#import <MobileCoreServices/MobileCoreServices.h>

@interface TTTSelectImageFun ()
<
    TZImagePickerControllerDelegate,
    UINavigationControllerDelegate,
    UIImagePickerControllerDelegate
>

@property(nonatomic, copy) SelectImageSuccessBlock successBlock;

@end

@implementation TTTSelectImageFun

- (void)showSelectImageAction:(long)selectCount successBlock:(SelectImageSuccessBlock)successBlock {
    
    self.successBlock = successBlock;
    
    QMUIAlertAction *action1 = [QMUIAlertAction actionWithTitle:@"取消" style:QMUIAlertActionStyleCancel handler:nil];
    
    QMUIAlertAction *action2 = [QMUIAlertAction actionWithTitle:@"拍照" style:QMUIAlertActionStyleDefault handler:^(QMUIAlertAction *action) {
        [TTTSysytemAuthority cameraAuthority:^(AuthorityStatus status) {
            if (status == SystemAuthoritySuccess) {
                dispatch_async(dispatch_get_main_queue(), ^{
                    if ([UIImagePickerController isSourceTypeAvailable:UIImagePickerControllerSourceTypeCamera]) {
                        UIImagePickerController *picker = [[UIImagePickerController alloc] init];
                        picker.delegate = self;
                        picker.allowsEditing = YES;  //是否可编辑
                        picker.sourceType = UIImagePickerControllerSourceTypeCamera;
                        [[WFOtherFun getCurrentVC] presentViewController:picker animated:YES completion:nil];
                    } else {
                         [QMUITips showWithText:@"请检查您的相机" inView:[WFOtherFun getCurrentVC].view hideAfterDelay:2.0];
                    }
                });
            }
        }];
    }];
    
    QMUIAlertAction *action3 = [QMUIAlertAction actionWithTitle:@"从相册选取" style:QMUIAlertActionStyleDefault handler:^(QMUIAlertAction *action) {
        TZImagePickerController *imagePickerVC = [[TZImagePickerController alloc] initWithMaxImagesCount:selectCount delegate:self];
        imagePickerVC.allowPickingOriginalPhoto = NO;
        imagePickerVC.sortAscendingByModificationDate = NO;
        imagePickerVC.naviTitleColor = UIColorWhite;
        [[WFOtherFun getCurrentVC] presentViewController:imagePickerVC animated:YES completion:nil];
    }];
    
    QMUIAlertController *alertController = [QMUIAlertController alertControllerWithTitle:@"请选择照片来源" message:nil preferredStyle:QMUIAlertControllerStyleActionSheet];
    [alertController addAction:action1];
    [alertController addAction:action2];
    [alertController addAction:action3];
    [alertController showWithAnimated:YES];
}

#pragma mark - TZImagePickerControllerDelegate
- (void)imagePickerController:(TZImagePickerController *)picker didFinishPickingPhotos:(NSArray<UIImage *> *)photos sourceAssets:(NSArray *)assets isSelectOriginalPhoto:(BOOL)isSelectOriginalPhoto {
    if (self.successBlock) {
        self.successBlock(photos);
    }
}

#pragma mark UINavigationControllerDelegate
// 用户选择取消
- (void)imagePickerController:(UIImagePickerController *)picker didFinishPickingMediaWithInfo:(NSDictionary *)info {
    NSString *type = [info objectForKey:UIImagePickerControllerMediaType];
    if ([type isEqualToString:(NSString *)kUTTypeImage] && picker.sourceType == UIImagePickerControllerSourceTypeCamera) {
        UIImage *original_image = [info objectForKey:@"UIImagePickerControllerOriginalImage"];
        UIImageWriteToSavedPhotosAlbum(original_image, nil,nil,nil);
    }
    [picker dismissViewControllerAnimated:YES completion:^{
        //获得编辑过的图片
        UIImage *image = [info objectForKey:@"UIImagePickerControllerEditedImage"];
        if (self.successBlock) {
            self.successBlock(@[image]);
        }
    }];
}


@end
