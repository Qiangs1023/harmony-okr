import { ApiAuthResult } from '../net/ApiClient';
import { SESSION } from '../store/SessionStore';
import { SYNC } from '../store/SyncService';

@ComponentV2
export struct LoginPanel {
  @Event onSignedIn: () => void = (): void => {
  };

  @Local username: string = '';
  @Local password: string = '';
  @Local isRegister: boolean = false;
  @Local busy: boolean = false;
  @Local errorText: string = '';
  @Local serverUrl: string = SESSION.baseUrl;
  @Local healthText: string = '';

  private title(): string {
    return this.isRegister ? '创建账号' : '登录';
  }

  private actionLabel(): string {
    if (this.busy) {
      return '处理中…';
    }
    return this.isRegister ? '注册并进入' : '登录';
  }

  private canSubmit(): boolean {
    return !this.busy
      && this.username.trim().length >= 3
      && this.password.length >= 6;
  }

  private toggleMode(): void {
    this.isRegister = !this.isRegister;
    this.errorText = '';
  }

  private saveServerUrl(): void {
    SESSION.setBaseUrl(this.serverUrl);
    this.healthText = '';
  }

  private async checkServer(): Promise<void> {
    this.saveServerUrl();
    this.busy = true;
    const result: string = await SYNC.health();
    this.busy = false;
    this.healthText = result === 'ok' ? '服务器连接正常' : `无法连接：${result}`;
  }

  private async submit(): Promise<void> {
    if (!this.canSubmit()) {
      return;
    }
    this.busy = true;
    this.errorText = '';
    SESSION.setBaseUrl(this.serverUrl);
    const result: ApiAuthResult = await SYNC.signIn(this.username.trim(), this.password, this.isRegister);
    this.busy = false;
    if (!result.ok) {
      this.errorText = result.error;
      return;
    }
    this.password = '';
    this.onSignedIn();
  }

  build() {
    Scroll() {
      Column({ space: 14 }) {
        Column({ space: 6 }) {
          Text('OKR 记事本')
            .fontSize(24)
            .fontWeight(FontWeight.Bold)
            .fontColor($r('app.color.okr_text_primary'))
          Text('登录后数据会在多设备之间同步')
            .fontSize(12)
            .fontColor($r('app.color.okr_text_secondary'))
        }
        .alignItems(HorizontalAlign.Start)
        .width('100%')

        Column({ space: 10 }) {
          TextInput({ placeholder: '用户名（至少 3 位）', text: this.username })
            .height(44)
            .fontSize(14)
            .backgroundColor($r('app.color.okr_bg'))
            .borderRadius(10)
            .onChange((value: string): void => {
              this.username = value;
            })
          TextInput({ placeholder: '密码（至少 6 位）', text: this.password })
            .type(InputType.Password)
            .height(44)
            .fontSize(14)
            .backgroundColor($r('app.color.okr_bg'))
            .borderRadius(10)
            .onChange((value: string): void => {
              this.password = value;
            })
        }
        .width('100%')
        .padding(14)
        .backgroundColor($r('app.color.okr_card'))
        .borderRadius(14)

        if (this.errorText.length > 0) {
          Text(this.errorText)
            .fontSize(12)
            .fontColor($r('app.color.okr_danger'))
            .width('100%')
        }

        Button(this.actionLabel())
          .width('100%')
          .height(46)
          .fontSize(15)
          .backgroundColor($r('app.color.okr_primary'))
          .fontColor('#FFFFFF')
          .enabled(this.canSubmit())
          .onClick((): void => {
            this.submit();
          })

        Row({ space: 16 }) {
          Text(this.isRegister ? '已有账号？去登录' : '还没有账号？去注册')
            .fontSize(13)
            .fontColor($r('app.color.okr_primary'))
            .onClick((): void => {
              this.toggleMode();
            })
          Text('换个服务器')
            .fontSize(13)
            .fontColor($r('app.color.okr_text_secondary'))
            .onClick((): void => {
              this.saveServerUrl();
            })
        }
        .width('100%')
        .justifyContent(FlexAlign.Center)

        Column({ space: 8 }) {
          TextInput({ placeholder: SESSION.baseUrl, text: this.serverUrl })
            .height(38)
            .fontSize(12)
            .backgroundColor($r('app.color.okr_bg'))
            .borderRadius(8)
            .onChange((value: string): void => {
              this.serverUrl = value;
              this.healthText = '';
            })
          Row({ space: 10 }) {
            Button('保存并测试连接')
              .height(32)
              .fontSize(12)
              .backgroundColor($r('app.color.okr_primary_soft'))
              .fontColor($r('app.color.okr_primary'))
              .onClick((): void => {
                this.checkServer();
              })
            Text(this.healthText)
              .fontSize(11)
              .fontColor($r('app.color.okr_text_secondary'))
              .layoutWeight(1)
          }
          .width('100%')
        }
        .width('100%')
        .padding(12)
        .backgroundColor($r('app.color.okr_card'))
        .borderRadius(12)
        .alignItems(HorizontalAlign.Start)
      }
      .width('100%')
      .padding({ left: 20, right: 20, top: 40, bottom: 24 })
    }
    .width('100%')
    .height('100%')
    .backgroundColor($r('app.color.okr_bg'))
    .scrollBar(BarState.Off)
  }
}
