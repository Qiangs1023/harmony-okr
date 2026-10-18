import { okrTagColor } from '../model/OkrModel';

@ComponentV2
export struct OkrTagChip {
  @Param chipText: string = '';
  @Param colorIndex: number = 0;
  @Param solid: boolean = false;

  private textColor(): ResourceColor {
    if (this.solid) {
      return '#FFFFFF';
    }
    return $r('app.color.okr_text_secondary');
  }

  private chipBg(): ResourceColor {
    if (this.solid) {
      return okrTagColor(this.colorIndex);
    }
    return $r('app.color.okr_track');
  }

  build() {
    Text(this.chipText)
      .fontSize(11)
      .fontWeight(FontWeight.Medium)
      .fontColor(this.textColor())
      .padding({ left: 8, right: 8, top: 3, bottom: 3 })
      .borderRadius(4)
      .backgroundColor(this.chipBg())
  }
}

@ComponentV2
export struct OkrSelectChip {
  @Param chipText: string = '';
  @Param active: boolean = false;
  @Param chipColor: ResourceColor = '#4E7BFF';
  @Event onPick: () => void = (): void => {
  };

  private textColor(): ResourceColor {
    if (this.active) {
      return '#FFFFFF';
    }
    return $r('app.color.okr_text_secondary');
  }

  private chipBg(): ResourceColor {
    if (this.active) {
      return this.chipColor;
    }
    return $r('app.color.okr_track');
  }

  build() {
    Text(this.chipText)
      .fontSize(12)
      .fontWeight(FontWeight.Medium)
      .fontColor(this.textColor())
      .padding({ left: 12, right: 12, top: 6, bottom: 6 })
      .borderRadius(14)
      .backgroundColor(this.chipBg())
      .onClick((): void => {
        this.onPick();
      })
  }
}

@ComponentV2
export struct OkrProgressTrack {
  @Param percent: number = 0;
  @Param barColor: ResourceColor = '#4E7BFF';
  @Param barHeight: number = 6;

  private safePercent(): number {
    if (this.percent < 0) {
      return 0;
    }
    if (this.percent > 100) {
      return 100;
    }
    return this.percent;
  }

  build() {
    Stack({ alignContent: Alignment.Start }) {
      Row()
        .width('100%')
        .height(this.barHeight)
        .borderRadius(this.barHeight / 2)
        .backgroundColor($r('app.color.okr_track'))
      Row()
        .width(`${this.safePercent()}%`)
        .height(this.barHeight)
        .borderRadius(this.barHeight / 2)
        .backgroundColor(this.barColor)
    }
    .width('100%')
    .height(this.barHeight)
  }
}

@ComponentV2
export struct OkrEmptyHint {
  @Param hintText: string = '还没有内容';
  @Param subText: string = '';

  build() {
    Column({ space: 6 }) {
      Text(this.hintText)
        .fontSize(15)
        .fontWeight(FontWeight.Medium)
        .fontColor($r('app.color.okr_text_tertiary'))
      if (this.subText.length > 0) {
        Text(this.subText)
          .fontSize(12)
          .fontColor($r('app.color.okr_text_tertiary'))
      }
    }
    .width('100%')
    .padding({ top: 48, bottom: 48 })
    .alignItems(HorizontalAlign.Center)
  }
}
