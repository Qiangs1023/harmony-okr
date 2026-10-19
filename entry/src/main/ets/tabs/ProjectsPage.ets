import { OkrFlowState } from '../model/OkrAnalytics';
import { OkrKrItem, OkrProjectItem, okrHashTag } from '../model/OkrModel';
import { OKR_STORE } from '../store/OkrStore';
import { OkrCardHead, OkrMeter, OkrPageHeader, OkrSolidButton } from '../components/OkrUi';

/** 项目 Tab：把目标、关键结果、任务串成一条线 */
@ComponentV2
export struct ProjectsPage {
  @Local draftOpen: boolean = false;
  @Local projTitle: string = '';
  @Local projDesc: string = '';

  @Event onOpenProject: (projectId: string) => void = (_projectId: string): void => {
  };

  private createProject(): void {
    if (this.projTitle.trim().length === 0) {
      return;
    }
    OKR_STORE.addProject(this.projTitle.trim(), this.projDesc.trim(), okrHashTag(this.projTitle.trim()));
    this.draftOpen = false;
    this.projTitle = '';
    this.projDesc = '';
  }

  private projectState(projectId: string): OkrFlowState {
    let worst: OkrFlowState = OkrFlowState.OnTrack;
    const list: OkrKrItem[] = OKR_STORE.krsOfProject(projectId);
    for (let i = 0; i < list.length; i++) {
      const state: OkrFlowState = OKR_STORE.krState(list[i].id);
      if (state === OkrFlowState.Behind) {
        return OkrFlowState.Behind;
      }
      if (state === OkrFlowState.Stalled) {
        worst = OkrFlowState.Stalled;
      }
    }
    return worst;
  }

  @Builder
  projectCard(project: OkrProjectItem) {
    Row({ space: 10 }) {
      Column({ space: 6 }) {
        Text(project.title)
          .fontSize(16)
          .fontWeight(FontWeight.Bold)
          .letterSpacing(-0.2)
          .fontColor($r('app.color.okr_text_primary'))

        if (project.desc.length > 0) {
          Text(project.desc)
            .fontSize(12.5)
            .fontWeight(FontWeight.Lighter)
            .lineHeight(20)
            .maxLines(2)
            .textOverflow({ overflow: TextOverflow.Ellipsis })
            .fontColor($r('app.color.okr_text_tertiary'))
        }

        OkrMeter({
          actual: OKR_STORE.projectProgress(project.id),
          expected: OKR_STORE.projectExpected(project.id),
          state: this.projectState(project.id),
          showLabel: false
        })

        Text(`${OKR_STORE.projectProgress(project.id)}% · ${OKR_STORE.krsOfProject(project.id).length} 个 KR · ` +
          `${OKR_STORE.ideasOfProject(project.id).length} 个任务`)
          .fontSize(10.5)
          .fontColor($r('app.color.okr_text_tertiary'))
      }
      .layoutWeight(1)
      .alignItems(HorizontalAlign.Start)

      Text('›')
        .fontSize(18)
        .fontColor($r('app.color.okr_ink_faint'))
    }
    .width('100%')
    .padding(18)
    .alignItems(VerticalAlign.Top)
    .backgroundColor($r('app.color.okr_card'))
    .borderRadius(16)
    .border({ width: 1, color: $r('app.color.okr_divider') })
    .shadow({ radius: 12, color: '#14111619', offsetX: 0, offsetY: 4 })
    .onClick((): void => {
      this.onOpenProject(project.id);
    })
  }

  @Builder
  composer() {
    Column({ space: 10 }) {
      Text('新建项目')
        .fontSize(16)
        .fontWeight(FontWeight.Bold)
        .fontColor($r('app.color.okr_text_primary'))
        .width('100%')

      TextInput({ placeholder: '项目名称，例如「冷启动」', text: this.projTitle })
        .height(42)
        .fontSize(13)
        .backgroundColor($r('app.color.okr_track'))
        .borderRadius(10)
        .onChange((value: string): void => {
          this.projTitle = value;
        })

      TextArea({ placeholder: '项目描述（选填）', text: this.projDesc })
        .height(70)
        .fontSize(13)
        .backgroundColor($r('app.color.okr_track'))
        .borderRadius(10)
        .onChange((value: string): void => {
          this.projDesc = value;
        })

      Row() {
        Blank()
        OkrSolidButton({
          label: '创建',
          onTap: (): void => {
            this.createProject();
          }
        })
      }
      .width('100%')
    }
    .width('100%')
    .padding({ left: 18, right: 18, top: 4, bottom: 20 })
    .alignItems(HorizontalAlign.Start)
    .backgroundColor($r('app.color.okr_bg'))
  }

  build() {
    Stack({ alignContent: Alignment.BottomEnd }) {
      Scroll() {
        Column({ space: 12 }) {
          OkrPageHeader({
            eyebrow: `${OKR_STORE.projectList(false).length} 个进行中`,
            title: '项目',
            sub: '把目标、关键结果、任务串成一条线'
          })

          if (OKR_STORE.projectList(false).length === 0) {
            Column({ space: 10 }) {
              OkrCardHead({ title: '还没有项目' })
              Text('点右下角的加号，把这季度真正要交付的东西列出来')
                .fontSize(12.5)
                .fontWeight(FontWeight.Lighter)
                .lineHeight(20)
                .fontColor($r('app.color.okr_text_tertiary'))
            }
            .width('100%')
            .padding(18)
            .alignItems(HorizontalAlign.Start)
            .backgroundColor($r('app.color.okr_card'))
            .borderRadius(16)
            .border({ width: 1, color: $r('app.color.okr_divider') })
          } else {
            ForEach(OKR_STORE.projectList(false), (project: OkrProjectItem): void => {
              this.projectCard(project)
            }, (project: OkrProjectItem): string => project.id)
          }
        }
        .width('100%')
        .padding({ left: 18, right: 18, top: 14, bottom: 24 })
      }
      .width('100%')
      .height('100%')
      .scrollBar(BarState.Off)

      Button('＋')
        .width(52)
        .height(52)
        .fontSize(26)
        .borderRadius(26)
        .backgroundColor($r('app.color.okr_text_primary'))
        .fontColor($r('app.color.okr_on_primary'))
        .shadow({ radius: 12, color: '#33000000', offsetX: 0, offsetY: 4 })
        .margin({ right: 20, bottom: 20 })
        .onClick((): void => {
          this.draftOpen = !this.draftOpen;
        })
    }
    .width('100%')
    .height('100%')
    .bindSheet($$this.draftOpen, this.composer(), {
      height: SheetSize.FIT_CONTENT,
      dragBar: true,
      showClose: true,
      keyboardAvoidMode: SheetKeyboardAvoidMode.TRANSLATE_AND_RESIZE
    })
  }
}
