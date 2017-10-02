// This file is a POC showing how an entire application, including its attributes,
// infrastructure and pipelines, could be defined within a declarative Spinnaker
// file. 
//
// This file represents the current Netflix prod clouddriver deployment. We've
// only included a single, simple pipeline as part of this demo.
//
// NOTE: This demo hand-waves over the stdlib (v1.jsonnetlib) implementation.
// The final, built, feature will likely deviate from this.
local s = import "v1.jsonnetlib";
local deliveryEngineering = import "spinnaker://det.jsonnetlib";
local spin = s.intent.SpinnakerFileType;
local application = s.intent.ApplicationType;
local notification = s.intent.NotificationType;
local cluster = s.intent.ClusterType;
local promotion = s.intent.PromotionWorkflowType;
local securityGroup = s.intent.aws.AwsSecurityGroupType;
local loadBalancer = s.intent.aws.AwsClassicLoadBalancerType;
local pipeline = s.intent.PipelineType;
local trigger = s.intent.TriggerType;
local parameter = s.intent.ParameterType;
local bakeStage = s.intent.stages.BakeStageType;
local upsertImageTagsStage = s.intent.stages.UpsertImageTagsStageType;

local redisGroup = "a";

local clusters = [
  {
    detail: redisGroup,
  },
  {
    detail: redisGroup + "-api",
  } + cluster.mixins.aws.simpleCapacity(6),
  {
    detail: redisGroup + "-api-readonly",
  },
  {
    detail: redisGroup + "-api-readonly-deck",
  },
  {
    detail: redisGroup + "-api-readonly-orca"
  },
  {
    detail: redisGroup + "-api-readonly-orca-1"
  },
  {
    detail: redisGroup + "-api-readonly-orca-2"
  },
  {
    detail: redisGroup + "-api-readonly-orca-3"
  },
  {
    detail: redisGroup + "-api-readonly-orca-4"
  },
];

local loadBalancers = ['', 'readonly', 'readonly-deck', 'readonly-orca', 'readonly-orca-1', 'readonly-orca-2', 'readonly-orca-3', 'readonly-orca-4'];

local app = application.new("clouddriver", "spinnaker@example.com", "cloud read and write operations") +
  application.mixins.group("spinnaker") +
  application.mixins.pagerDuty("Spinnaker") +
  application.mixins.cloudProviders("aws") +
  application.mixins.notifications(
    notification.slack("#example", [
      notification.mixins.complete(),
      notification.mixins.failed()
    ])
  ) +
  application.mixins.features.disabled("timeline") +
  application.mixins.trafficGuards({ account: "mgmt", region: "*", stack: "*", detail: "*" }) +
  application.mixins.pipelines(
    pipeline.new("Bake and Tag") +
      pipeline.mixins.triggers(trigger.newJenkins("spinnaker", "clouddriver-package")) +
      pipeline.mixins.parameters(
        parameter.new("isRedisReplacement", "Is this deployment into a new redis instance?") +
          parameter.mixins.defaultValue("false") +
          parameter.mixins.options("false", "true")
      ) +
      pipeline.mixins.stages(
        bakeStage.new("Bake") + {
          "baseOs": "xenial",
          "cloudProviderType": "aws",
          "package": "clouddriver",
          "regions": ["us-east-1", "us-west-2"],
          "storeType": "ebs",
        },
        upsertImageTagsStage.new("Tag Image") +
          upsertImageTagsStage.mixins.aws() + 
          upsertImageTagsStage.mixins.tags("test")
      )
  ) +
  application.mixins.securityGroups([
    securityGroup.new("clouddriver", "Security group for clouddriver") + 
      securityGroup.mixins.rules(securityGroup.mixins.ingress("clouddriver", "tcp", 6379, 6379)),
    // remote imported: The spinnaker-internal-service security group is shared
    // by most services and defined elsewhere.
    deliveryEngineering.mixins.securityGroup.internalService()
  ]) +
  application.mixins.loadBalancers([
    loadBalancer.new(lbDetail) + 
      loadBalancer.mixins.internal() +
      loadBalancer.mixins.securityGroups(deliveryEngineering.mixins.securityGroup.internalServiceElb()) +
      loadBalancer.mixins.listeners([
        loadBalancer.mixins.listener("http", 80, "http", 7001),
        loadBalancer.mixins.listener("tcp", 443, "tcp", 7002)
      ]) +
      loadBalancer.mixins.healthCheck("http", 7001, "/health") + {
        timeout: 5,
        interval: 10,
        healthyThreshold: 5,
        unhealthyThreshold: 5,
      }
    for lbDetail in loadBalancers
  ]) +

  // FUTURE FEATURE (Concept-only)
  // Defining clusters & promotionWorkflow is an alternative to explicit pipeline
  // definitions. When these two are defined, Spinnaker is able to infer basic
  // pipelines that need to be created to release software. If the inferred
  // pipelines do not fit, they can be individually substituted case-by-case.
  application.mixins.clusters([
    // Defines a root-level (incomplete) cluster definition that is made concrete
    // by the clusters variable. The stdlib would have default values that raise
    // errors if they're not overridden.
    cluster.new() +
      // TODO rz - I think placement could be inferred, but I don't know where
      // this information would be provided otherwise or how to intelligently
      // figure it out yet.
      // cluster.mixins.aws.placement("mgmt", ["us-west-2"], "internal (vpc0)") +
      cluster.mixins.aws.simpleCapacity(4) +
      cluster.mixins.strategy.redblack(2, false) +
      cluster.mixins.securityGroups([
        "clouddriver",
        "spinnaker-internal-service"
      ]) +
      cluster.mixins.aws.scalingProcessesExcept("AZRebalance") + {
        detail: c.detail,
        instanceType: "c3.2xlarge",
        keyName: "myKeyPairExample",
        iamInstanceProfile: "clouddriverInstanceProfile"
      }
    for c in clusters
  ]) + 
  application.mixins.promotionWorkflow(
    // Defines an ordered promotion workflow for an application to progress
    // through. Both accounts & stacks can be arrays or single strings. If we
    // wanted to customize the promotion workflow (e.g. "don't use the default,
    // inferred pipeline topology, use this specific pipeline instead") would 
    // probably be defined here as well.
    // TODO rz - still needs a way to set policy constraints for moving into a
    // new phase, whereas this really is more about placement instead of policy
    // enforcement.
    promotion.new() +
      promotion.mixins.phase(0, "mgmttest", "test", "us-west-2") +
      promotion.mixins.phase(1, "mgmt", ["loadtemp", "main"], ["us-west-2", "us-east-1"])
  );

spin.new(app)
