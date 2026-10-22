/** 自定义任务类型（表 task_type，种子数据 id 与旧数值兼容：0 日常 / 1 作业 / 2 备考） */
export class TaskCategory {
  id: number = 0;
  name: string = '';

  constructor(id: number = 0, name: string = '') {
    this.id = id;
    this.name = name;
  }
}

/** 自定义优先级档位（表 task_priority，id 越大档位越高，种子：0 低 / 1 中 / 2 高） */
export class PriorityLevel {
  id: number = 0;
  name: string = '';

  constructor(id: number = 0, name: string = '') {
    this.id = id;
    this.name = name;
  }
}

export interface CategoryPair {
  types: TaskCategory[];
  prios: PriorityLevel[];
}
