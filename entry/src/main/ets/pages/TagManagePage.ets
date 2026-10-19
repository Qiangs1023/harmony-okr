import { okrTagColor, OkrTagItem } from '../model/OkrModel';
import { OKR_STORE } from '../store/OkrStore';
import { PageShell, SectionCard } from '../components/PageShell';

@ComponentV2
export struct TagManagePage {
  @Local stack: NavPathStack = new NavPathStack();
  @Local newTagName: string = '';
  @Local newTagColor: number = 0;
  @Local editingName: string = '';
  @Local editingValue: string = '';

  private tags(): OkrTagItem[] {
    return OKR_STORE.tags;
  }

  private usageCount(name: string): number {
    return OKR_STORE.ideas.filter((item): boolean => item.tags.indexOf(name) >= 0).length;
  }

  private createTag(): void {
    const name: string = this.newTagName.trim();
    if (name.length === 0) {
      return;
    }
    if (OKR_STORE.hasTag(name)) {
      this.getUIContext().getPromptAction().showToast({ message: '标签已存在' });
      return;
    }
    OKR_STORE.createTag(name, this.newTagColor);
    this.newTagName = '';
  }

  private startRename(name: string): void {
    this.editingName = name;
    this.editingValue = name;
  }

  private applyRename(): void {
    if (this.editingName.length === 0) {
      return;
    }
    OKR_STORE.renameTag(this.editingName, this.editingValue);
    this.editingName = '';
    this.editingValue = '';
  }

  private removeTag(name: string): void {
    AlertDialog.show({
      title: '删除标签',
      message: `会从 ${this.usageCount(name)} 条任务上移除该标签，任务本身不删除。`,
      primaryButton: { value: '取消', action: (): void => {
      } },
      secondaryButton: { value: '删除', fontColor: $r('app.color.okr_danger'), action: (): void => {
        OKR_STORE.deleteTag(name);
      } }
    });
  }

  @Builder
  topBar() {
    Row() {
      Text('‹ 返回')
        .fontSize(14)
        .fontColor($r('app.color.okr_primary'))
        .onClick((): void => {
          this.stack.pop();
        })
      Text('标签管理')
        .fontSize(16)
        .fontWeight(FontWeight.Bold)
        .fontColor($r('app.color.okr_text_primary'))
        .layoutWeight(1)
        .textAlign(TextAlign.Center)
      Blank()
    }
    .width('100%')
    .height(44)
    .alignItems(VerticalAlign.Center)
  }

  @Builder
  colorPicker(onPick: (index: number) => void, current: number) {
    Scroll() {
      Row({ space: 8 }) {
        ForEach([0, 1, 2, 3, 4, 5, 6, 7], (index: number): void => {
          Row()
            .width(26)
            .height(26)
            .backgroundColor(okrTagColor(index))
            .borderRadius(13)
            .border({ width: current === index ? 2 : 0, color: $r('app.color.okr_text_primary') })
            .onClick((): void => {
              onPick(index);
            })
        }, (index: number): string => `${index}`)
      }
    }
    .width('100%')
    .height(32)
    .scrollable(ScrollDirection.Horizontal)
    .scrollBar(BarState.Off)
  }

  build() {
    NavDestination() {
      PageShell() {
        this.topBar()

        Column({ space: 14 }) {
          SectionCard({ cardTitle: '新建标签' }) {
            TextInput({ placeholder: '标签名', text: this.newTagName })
              .height(40)
              .fontSize(13)
              .backgroundColor($r('app.color.okr_bg'))
              .borderRadius(10)
              .onChange((value: string): void => {
                this.newTagName = value;
              })
            this.colorPicker((index: number): void => {
              this.newTagColor = index;
            }, this.newTagColor)
            Button('创建')
              .width('100%')
              .height(40)
              .fontSize(14)
              .backgroundColor($r('app.color.okr_primary'))
              .fontColor($r('app.color.okr_on_primary'))
              .onClick((): void => {
                this.createTag();
              })
          }

          if (this.tags().length === 0) {
            Text('还没有标签。在快速记录里写 #标签 会自动创建。')
              .fontSize(12)
              .fontColor($r('app.color.okr_text_tertiary'))
              .width('100%')
          }

          ForEach(this.tags(), (item: OkrTagItem) => {
            SectionCard({ cardTitle: item.name }) {
              Column({ space: 8 }) {
              if (this.editingName === item.name) {
                TextInput({ placeholder: '新的标签名', text: this.editingValue })
                  .height(38)
                  .fontSize(13)
                  .backgroundColor($r('app.color.okr_bg'))
                  .borderRadius(8)
                  .onChange((value: string): void => {
                    this.editingValue = value;
                  })
                Row({ space: 8 }) {
                  Button('保存')
                    .layoutWeight(1)
                    .height(34)
                    .fontSize(12)
                    .backgroundColor($r('app.color.okr_primary'))
                    .fontColor($r('app.color.okr_on_primary'))
                    .onClick((): void => {
                      this.applyRename();
                    })
                  Button('取消')
                    .layoutWeight(1)
                    .height(34)
                    .fontSize(12)
                    .backgroundColor($r('app.color.okr_track'))
                    .fontColor($r('app.color.okr_text_primary'))
                    .onClick((): void => {
                      this.editingName = '';
                    })
                }
                .width('100%')
              } else {
                Row({ space: 8 }) {
                  Row()
                    .width(14)
                    .height(14)
                    .backgroundColor(okrTagColor(item.colorIndex))
                    .borderRadius(7)
                  Text(item.name)
                    .fontSize(14)
                    .fontColor($r('app.color.okr_text_primary'))
                    .layoutWeight(1)
                  Text(`${this.usageCount(item.name)} 条`)
                    .fontSize(11)
                    .fontColor($r('app.color.okr_text_tertiary'))
                  Text('改名')
                    .fontSize(12)
                    .fontColor($r('app.color.okr_primary'))
                    .onClick((): void => {
                      this.startRename(item.name);
                    })
                  Text('删除')
                    .fontSize(12)
                    .fontColor($r('app.color.okr_danger'))
                    .onClick((): void => {
                      this.removeTag(item.name);
                    })
                }
                .width('100%')
                this.colorPicker((index: number): void => {
                  OKR_STORE.setTagColor(item.name, index);
                }, item.colorIndex)
              }
              }
            }
          }, (item: OkrTagItem): string => item.name)
        }
        .width('100%')
        .padding({ left: 16, right: 16, bottom: 24 })
      }
    }
    .hideTitleBar(true)
    .backgroundColor($r('app.color.okr_bg'))
    .onReady((context: NavDestinationContext): void => {
      this.stack = context.pathStack;
    })
  }
}

@Builder
export function TagManageBuilder() {
  TagManagePage()
}
