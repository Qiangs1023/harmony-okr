/** 底部标签栏：图标 + 文字，选中项顶部有一道 16×2 的墨色指示线 */

/** 图标路径直接写在 19×19 的用户坐标系里（对齐 24 格原稿等比缩小），避免依赖 viewPort */

const ICON_TODAY: string =
  'M9.5 6.33 A3.17 3.17 0 1 0 9.5 12.67 A3.17 3.17 0 1 0 9.5 6.33 ' +
  'M9.5 2.4 L9.5 3.96 M9.5 15.04 L9.5 16.6 M2.4 9.5 L3.96 9.5 M15.04 9.5 L16.6 9.5 ' +
  'M3.88 3.88 L4.97 4.97 M14.03 14.03 L15.12 15.12 M3.88 15.12 L4.97 14.03 M14.03 4.97 L15.12 3.88';

const ICON_GOALS: string =
  'M9.5 3.17 A6.33 6.33 0 1 0 9.5 15.83 A6.33 6.33 0 1 0 9.5 3.17 ' +
  'M9.5 6.81 A2.69 2.69 0 1 0 9.5 12.19 A2.69 2.69 0 1 0 9.5 6.81 ' +
  'M9.5 3.17 L9.5 1.6 M15.83 9.5 L17.4 9.5 M9.5 15.83 L9.5 17.4 M3.17 9.5 L1.6 9.5';

const ICON_REVIEW: string =
  'M3.17 3.96 L15.83 3.96 M3.17 9.5 L11.08 9.5 M3.17 15.04 L8.71 15.04 ' +
  'M13.46 12.27 L15.04 13.86 L17.78 10.71';

const ICON_INSIGHTS: string = 'M3.17 7.13 L3.17 15.04 M7.92 3.96 L7.92 15.04 M12.67 10.29 L12.67 15.04 M17.42 15.04 L1.58 15.04';

@ComponentV2
export struct TabIcon {
  @Param kind: number = 0;
  @Param active: boolean = false;

  private commands(): string {
    if (this.kind === 1) {
      return ICON_GOALS;
    }
    if (this.kind === 2) {
      return ICON_REVIEW;
    }
    if (this.kind === 3) {
      return ICON_INSIGHTS;
    }
    return ICON_TODAY;
  }

  private strokeColor(): ResourceColor {
    return this.active ? $r('app.color.okr_text_primary') : $r('app.color.okr_ink_faint');
  }

  build() {
    Path({ commands: this.commands() })
      .width(19)
      .height(19)
      .fill(Color.Transparent)
      .stroke(this.strokeColor())
      .strokeWidth(1.7)
      .strokeLineCap(LineCapStyle.Round)
      .strokeLineJoin(LineJoinStyle.Round)
  }
}

@ComponentV2
export struct OkrTabBar {
  @Param activeIndex: number = 0;
  @Event onChange: (index: number) => void = (_index: number): void => {
  };

  private labels(): string[] {
    return ['今天', '目标', '对齐', '洞察'];
  }

  @Builder
  tabItem(index: number) {
    Column({ space: 6 }) {
      Row()
        .width(16)
        .height(2)
        .borderRadius(1)
        .backgroundColor($r('app.color.okr_text_primary'))
        .opacity(this.activeIndex === index ? 1 : 0)

      TabIcon({ kind: index, active: this.activeIndex === index })

      Text(this.labels()[index])
        .fontSize(10.5)
        .fontWeight(this.activeIndex === index ? FontWeight.Medium : FontWeight.Normal)
        .fontColor(this.activeIndex === index ? $r('app.color.okr_text_primary') : $r('app.color.okr_ink_faint'))
    }
    .layoutWeight(1)
    .height(58)
    .justifyContent(FlexAlign.Center)
    .onClick((): void => {
      this.onChange(index);
    })
  }

  build() {
    Row() {
      this.tabItem(0)
      this.tabItem(1)
      this.tabItem(2)
      this.tabItem(3)
    }
    .width('100%')
    .height(58)
    .backgroundColor($r('app.color.okr_card'))
    .border({ width: 0 })
    .borderWidth({ top: 1, right: 0, bottom: 0, left: 0 })
    .borderColor({ top: $r('app.color.okr_divider'), right: '#00000000', bottom: '#00000000', left: '#00000000' })
  }
}
