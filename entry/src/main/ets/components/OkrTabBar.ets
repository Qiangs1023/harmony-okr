/** 底部标签栏：纯文字，选中项顶部有一道 16×2 的墨色指示线 */

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
    Column({ space: 8 }) {
      Row()
        .width(16)
        .height(2)
        .borderRadius(1)
        .backgroundColor($r('app.color.okr_text_primary'))
        .opacity(this.activeIndex === index ? 1 : 0)

      Text(this.labels()[index])
        .fontSize(14)
        .fontWeight(this.activeIndex === index ? FontWeight.Bold : FontWeight.Normal)
        .fontColor(this.activeIndex === index ? $r('app.color.okr_text_primary') : $r('app.color.okr_ink_faint'))
    }
    .layoutWeight(1)
    .height(52)
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
    .height(52)
    .backgroundColor($r('app.color.okr_card'))
    .borderWidth({ top: 1, right: 0, bottom: 0, left: 0 })
    .borderColor({ top: $r('app.color.okr_divider'), right: '#00000000', bottom: '#00000000', left: '#00000000' })
  }
}
