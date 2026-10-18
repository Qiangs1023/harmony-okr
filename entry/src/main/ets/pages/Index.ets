import { BusinessError } from '@kit.BasicServicesKit';
import { IdeaCard } from '../components/IdeaCard';
import { LoginPanel } from '../components/LoginPanel';
import { OkrEmptyHint } from '../components/OkrCommon';
import { ObjectiveCard } from '../components/ObjectiveCard';
import { QuickCapture } from '../components/QuickCapture';
import { TagFilterBar } from '../components/TagFilterBar';
import { OkrIdeaItem, OkrIdeaParam, OkrKrParam, OkrObjectiveItem } from '../model/OkrModel';
import { OKR_STORE } from '../store/OkrStore';
import { SESSION } from '../store/SessionStore';
import { SYNC } from '../store/SyncService';

@Entry
@ComponentV2
struct Index {
  @Local pathStack: NavPathStack = new NavPathStack();
  @Local currentTab: number = 0;
  @Local objectiveComposerOpen: boolean = false;
  @Local objTitle: string = '';
  @Local objPeriod: string = '';
  @Local objDesc: string = '';

  private visibleIdeas(): OkrIdeaItem[] {
    return OKR_STORE.visibleIdeas();
  }

  private objectiveList(): OkrObjectiveItem[] {
    return OKR_STORE.objectives;
  }

  private headerSub(): string {
    return `待办 ${OKR_STORE.todoCount()} 条 · 今日完成 ${OKR_STORE.doneTodayCount()} 条`;
  }

  private openIdea(ideaId: string): void {
    const param: OkrIdeaParam = { ideaId: ideaId };
    this.pathStack.pushDestination({ name: 'IdeaDetail', param: param })
      .catch((error: BusinessError): void => {
        console.error(`open idea failed: ${error.message}`);
      });
  }

  private openKr(krId: string): void {
    const param: OkrKrParam = { objectiveId: OKR_STORE.krObjectiveId(krId), krId: krId };
    this.pathStack.pushDestination({ name: 'KrDetail', param: param })
      .catch((error: BusinessError): void => {
        console.error(`open kr failed: ${error.message}`);
      });
  }

  private objectiveButtonLabel(): string {
    if (this.objectiveComposerOpen) {
      return '收起';
    }
    return '＋ 新目标';
  }

  private toggleObjectiveComposer(): void {
    this.objectiveComposerOpen = !this.objectiveComposerOpen;
    this.objTitle = '';
    this.objPeriod = '';
    this.objDesc = '';
  }

  private createObjective(): void {
    if (this.objTitle.trim().length === 0) {
      return;
    }
    OKR_STORE.addObjective(this.objTitle.trim(), this.objPeriod.trim(), this.objDesc.trim());
    this.objectiveComposerOpen = false;
    this.objTitle = '';
    this.objPeriod = '';
    this.objDesc = '';
  }

  @Builder
  homeHeader() {
    Row() {
      Column({ space: 3 }) {
        Text('OKR 记事本')
          .fontSize(21)
          .fontWeight(FontWeight.Bold)
          .fontColor($r('app.color.okr_text_primary'))
        Text(this.headerSub())
          .fontSize(12)
          .fontColor($r('app.color.okr_text_secondary'))
      }
      .alignItems(HorizontalAlign.Start)
      .layoutWeight(1)

      Text(SYNC.statusText())
        .fontSize(11)
        .fontColor($r('app.color.okr_text_tertiary'))
        .onClick((): void => {
          SYNC.syncNow();
        })
    }
    .width('100%')
    .padding({ left: 4, right: 4 })
    .alignItems(VerticalAlign.Center)
  }

  @Builder
  inboxTab() {
    Column({ space: 12 }) {
      QuickCapture()
      TagFilterBar()
      if (this.visibleIdeas().length === 0) {
        List() {
          ListItem() {
            OkrEmptyHint({
              hintText: OKR_STORE.activeTag.length > 0 ? '该标签下还没有内容' : '收件箱是空的',
              subText: OKR_STORE.activeTag.length > 0 ? '换个标签看看' : '在上方输入框写下第一个想法'
            })
          }
        }
        .width('100%')
        .layoutWeight(1)
        .scrollBar(BarState.Off)
      } else {
        List({ space: 10 }) {
          ForEach(this.visibleIdeas(), (ideaItem: OkrIdeaItem) => {
            ListItem() {
              IdeaCard({
                ideaId: ideaItem.id,
                onOpen: (id: string): void => {
                  this.openIdea(id);
                }
              })
            }
          }, (ideaItem: OkrIdeaItem): string => ideaItem.id)
        }
        .width('100%')
        .layoutWeight(1)
        .scrollBar(BarState.Off)
      }
    }
    .width('100%')
    .height('100%')
    .padding({ left: 16, right: 16 })
  }

  @Builder
  goalComposer() {
    Column({ space: 8 }) {
      TextInput({ placeholder: '目标，例如「打造个人 OKR 闭环」', text: this.objTitle })
        .height(40)
        .fontSize(13)
        .backgroundColor($r('app.color.okr_bg'))
        .borderRadius(8)
        .onChange((value: string): void => {
          this.objTitle = value;
        })
      Row({ space: 8 }) {
        TextInput({ placeholder: '周期（选填）', text: this.objPeriod })
          .layoutWeight(1)
          .height(40)
          .fontSize(13)
          .backgroundColor($r('app.color.okr_bg'))
          .borderRadius(8)
          .onChange((value: string): void => {
            this.objPeriod = value;
          })
        Button('创建')
          .width(80)
          .height(40)
          .fontSize(13)
          .backgroundColor($r('app.color.okr_primary'))
          .fontColor('#FFFFFF')
          .onClick((): void => {
            this.createObjective();
          })
      }
      .width('100%')
    }
    .width('100%')
    .padding(12)
    .alignItems(HorizontalAlign.Start)
    .backgroundColor($r('app.color.okr_card'))
    .borderRadius(14)
  }

  @Builder
  goalsTab() {
    Column({ space: 12 }) {
      Row() {
        Text('目标与关键结果')
          .fontSize(15)
          .fontWeight(FontWeight.Bold)
          .fontColor($r('app.color.okr_text_primary'))
          .layoutWeight(1)
        Button(this.objectiveButtonLabel())
          .height(32)
          .fontSize(12)
          .backgroundColor($r('app.color.okr_primary_soft'))
          .fontColor($r('app.color.okr_primary'))
          .onClick((): void => {
            this.toggleObjectiveComposer();
          })
      }
      .width('100%')
      .alignItems(VerticalAlign.Center)

      if (this.objectiveComposerOpen) {
        this.goalComposer()
      }

      if (this.objectiveList().length === 0) {
        List() {
          ListItem() {
            OkrEmptyHint({
              hintText: '还没有目标',
              subText: '点右上角「＋ 新目标」开始设定'
            })
          }
        }
        .width('100%')
        .layoutWeight(1)
        .scrollBar(BarState.Off)
      } else {
        List({ space: 12 }) {
          ForEach(this.objectiveList(), (objItem: OkrObjectiveItem) => {
            ListItem() {
              ObjectiveCard({
                objectiveId: objItem.id,
                onOpenKr: (id: string): void => {
                  this.openKr(id);
                }
              })
            }
          }, (objItem: OkrObjectiveItem): string => objItem.id)
        }
        .width('100%')
        .layoutWeight(1)
        .scrollBar(BarState.Off)
      }
    }
    .width('100%')
    .height('100%')
    .padding({ left: 16, right: 16 })
  }

  build() {
    Column() {
      if (SESSION.isLoggedIn()) {
        Navigation(this.pathStack) {
          Column({ space: 12 }) {
            this.homeHeader()
            Tabs({ index: this.currentTab }) {
              TabContent() {
                this.inboxTab()
              }
              .tabBar('收件箱')

              TabContent() {
                this.goalsTab()
              }
              .tabBar('目标')
            }
            .barMode(BarMode.Fixed)
            .barHeight(56)
            .divider({ strokeWidth: 1, color: $r('app.color.okr_divider') })
            .backgroundColor($r('app.color.okr_bg'))
            .onChange((index: number): void => {
              this.currentTab = index;
            })
            .layoutWeight(1)
          }
          .width('100%')
          .height('100%')
          .padding({ left: 16, right: 16, top: 12 })
          .backgroundColor($r('app.color.okr_bg'))
        }
        .mode(NavigationMode.Stack)
        .hideTitleBar(true)
        .width('100%')
        .height('100%')
      } else {
        LoginPanel({
          onSignedIn: (): void => {
            SYNC.start();
          }
        })
      }
    }
    .width('100%')
    .height('100%')
    .backgroundColor($r('app.color.okr_bg'))
  }
}
