export class Output {
  id: number;
  name: string;
  type: string;
  description: string;
  enabled: boolean;
  email_settings: OutputEmailConfig; // tslint:disable-line
  bus_settings: OutputBusConfig; // tslint:disable-line

  constructor() { };
}

export class OutputEmailConfig {
  from: string;
  to: number;
  body: string;
}

export class OutputBusConfig {
  address: string;
  port: number;
  type: string;
  mono_ontime: number; // tslint:disable-line
  mono_offtime: number; // tslint:disable-line
}
